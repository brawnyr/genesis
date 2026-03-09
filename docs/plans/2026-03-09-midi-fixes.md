# MIDI System Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix thread safety, add Note Off handling, add CC knob per-channel volume, and add MIDI test coverage.

**Architecture:** Replace the current main-thread dispatch from MIDI callback with a lock-free ring buffer. The MIDI callback (CoreMIDI thread) writes events; `processBlock` (audio thread) drains them. This eliminates all data races. Voice and Layer gain new fields to support Note Off and per-channel volume.

**Tech Stack:** Swift 5.9, CoreMIDI, Swift Testing

---

### Task 1: MIDIEvent Enum and MIDIRingBuffer

**Files:**
- Create: `GOD/GOD/Engine/MIDIRingBuffer.swift`
- Test: `Tests/MIDIRingBufferTests.swift`

**Step 1: Write the failing tests**

In `Tests/MIDIRingBufferTests.swift`:

```swift
import Testing
@testable import GOD

@Test func ringBufferWriteAndDrain() {
    var buffer = MIDIRingBuffer()
    buffer.write(.noteOn(note: 36, velocity: 100))
    buffer.write(.noteOn(note: 37, velocity: 80))

    var events: [MIDIEvent] = []
    buffer.drain { events.append($0) }

    #expect(events.count == 2)
    if case .noteOn(let note, let vel) = events[0] {
        #expect(note == 36)
        #expect(vel == 100)
    } else {
        Issue.record("Expected noteOn")
    }
    if case .noteOn(let note, let vel) = events[1] {
        #expect(note == 37)
        #expect(vel == 80)
    } else {
        Issue.record("Expected noteOn")
    }
}

@Test func ringBufferDrainEmpty() {
    var buffer = MIDIRingBuffer()
    var events: [MIDIEvent] = []
    buffer.drain { events.append($0) }
    #expect(events.count == 0)
}

@Test func ringBufferOverflow() {
    var buffer = MIDIRingBuffer()
    // Fill past capacity (256)
    for i in 0..<300 {
        buffer.write(.noteOn(note: i % 128, velocity: 100))
    }
    var events: [MIDIEvent] = []
    buffer.drain { events.append($0) }
    // Should get 256 (capacity), oldest dropped
    #expect(events.count == 256)
}

@Test func ringBufferNoteOff() {
    var buffer = MIDIRingBuffer()
    buffer.write(.noteOff(note: 36))
    var events: [MIDIEvent] = []
    buffer.drain { events.append($0) }
    #expect(events.count == 1)
    if case .noteOff(let note) = events[0] {
        #expect(note == 36)
    } else {
        Issue.record("Expected noteOff")
    }
}

@Test func ringBufferCC() {
    var buffer = MIDIRingBuffer()
    buffer.write(.cc(number: 14, value: 64))
    var events: [MIDIEvent] = []
    buffer.drain { events.append($0) }
    #expect(events.count == 1)
    if case .cc(let num, let val) = events[0] {
        #expect(num == 14)
        #expect(val == 64)
    } else {
        Issue.record("Expected cc")
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd /Users/brawny/god/GOD && swift test --filter MIDIRingBuffer 2>&1 | tail -20`
Expected: Compilation error — `MIDIEvent` and `MIDIRingBuffer` not found.

**Step 3: Implement MIDIEvent and MIDIRingBuffer**

In `GOD/GOD/Engine/MIDIRingBuffer.swift`:

```swift
import Foundation

enum MIDIEvent {
    case noteOn(note: Int, velocity: Int)
    case noteOff(note: Int)
    case cc(number: Int, value: Int)
}

struct MIDIRingBuffer {
    private var buffer = [MIDIEvent?](repeating: nil, count: 256)
    private var writeIndex: Int = 0
    private var readIndex: Int = 0

    mutating func write(_ event: MIDIEvent) {
        buffer[writeIndex % 256] = event
        writeIndex += 1
        // If we've lapped the reader, advance reader (drop oldest)
        if writeIndex - readIndex > 256 {
            readIndex = writeIndex - 256
        }
    }

    mutating func drain(_ handler: (MIDIEvent) -> Void) {
        while readIndex < writeIndex {
            if let event = buffer[readIndex % 256] {
                handler(event)
            }
            readIndex += 1
        }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd /Users/brawny/god/GOD && swift test --filter MIDIRingBuffer 2>&1 | tail -20`
Expected: All 5 tests PASS.

**Step 5: Commit**

```bash
cd /Users/brawny/god
git add GOD/GOD/Engine/MIDIRingBuffer.swift GOD/Tests/MIDIRingBufferTests.swift
git commit -m "feat: add MIDIEvent enum and lock-free MIDIRingBuffer"
```

---

### Task 2: Add volume to Layer, padIndex to Voice, isOneShot to Pad

**Files:**
- Modify: `GOD/GOD/Models/Layer.swift:8` — add `volume` property
- Modify: `GOD/GOD/Models/Voice.swift:3` — add `padIndex` property
- Modify: `GOD/GOD/Models/Pad.swift:3` — add `isOneShot` property
- Test: `Tests/MIDITests.swift`

**Step 1: Write the failing tests**

In `Tests/MIDITests.swift`:

```swift
import Testing
@testable import GOD

@Test func layerHasVolume() {
    var layer = Layer(index: 0, name: "TEST")
    #expect(layer.volume == 1.0)
    layer.volume = 0.5
    #expect(layer.volume == 0.5)
}

@Test func voiceHasPadIndex() {
    let sample = Sample(name: "test", data: [0.1, 0.2], sampleRate: 44100)
    let voice = Voice(sample: sample, velocity: 1.0, padIndex: 3)
    #expect(voice.padIndex == 3)
}

@Test func padHasIsOneShot() {
    var pad = Pad(index: 0, midiNote: 36, name: "TEST")
    #expect(pad.isOneShot == true)
    pad.isOneShot = false
    #expect(pad.isOneShot == false)
}
```

**Step 2: Run tests to verify they fail**

Run: `cd /Users/brawny/god/GOD && swift test --filter MIDITests 2>&1 | tail -20`
Expected: Compilation errors — `volume`, `padIndex`, `isOneShot` not found.

**Step 3: Add the properties**

In `GOD/GOD/Models/Layer.swift`, add to `Layer` struct after `isMuted`:
```swift
var volume: Float = 1.0
```

In `GOD/GOD/Models/Voice.swift`, add to `Voice` struct after `velocity`:
```swift
var padIndex: Int = -1
```

In `GOD/GOD/Models/Pad.swift`, add to `Pad` struct after `samplePath`:
```swift
var isOneShot: Bool = true
```

**Step 4: Run tests to verify they pass**

Run: `cd /Users/brawny/god/GOD && swift test --filter MIDITests 2>&1 | tail -20`
Expected: All 3 tests PASS.

**Step 5: Run all existing tests to check nothing broke**

Run: `cd /Users/brawny/god/GOD && swift test 2>&1 | tail -20`
Expected: All tests PASS. Existing code uses `Voice(sample:velocity:)` — since `padIndex` has a default value of `-1`, existing call sites still compile.

**Step 6: Commit**

```bash
cd /Users/brawny/god
git add GOD/GOD/Models/Layer.swift GOD/GOD/Models/Voice.swift GOD/GOD/Models/Pad.swift GOD/Tests/MIDITests.swift
git commit -m "feat: add volume to Layer, padIndex to Voice, isOneShot to Pad"
```

---

### Task 3: Wire MIDIManager to use ring buffer instead of main-thread dispatch

**Files:**
- Modify: `GOD/GOD/Engine/MIDIManager.swift:4-96` — replace engine reference with ring buffer, parse Note Off and CC
- Modify: `GOD/GOD/Engine/GodEngine.swift` — own the ring buffer, remove `onPadHit` main-thread path

**Step 1: Update MIDIManager to write to ring buffer**

Replace `MIDIManager` to hold a pointer to the ring buffer instead of the engine. The full new `MIDIManager.swift`:

```swift
import CoreMIDI
import Foundation

class MIDIManager: ObservableObject {
    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private var ringBuffer: UnsafeMutablePointer<MIDIRingBuffer>

    @Published var connectedDevice: String = "None"

    init(ringBuffer: UnsafeMutablePointer<MIDIRingBuffer>) {
        self.ringBuffer = ringBuffer
    }

    func start() {
        MIDIClientCreateWithBlock("GOD" as CFString, &midiClient) { [weak self] notification in
            self?.handleMIDINotification(notification)
        }

        MIDIInputPortCreateWithProtocol(
            midiClient,
            "GOD Input" as CFString,
            ._1_0,
            &inputPort
        ) { [weak self] eventList, _ in
            self?.handleMIDIEvents(eventList)
        }

        connectToMiniLab()
    }

    private func connectToMiniLab() {
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(source, kMIDIPropertyDisplayName, &name)

            if let deviceName = name?.takeRetainedValue() as String? {
                let lower = deviceName.lowercased()
                if lower.contains("minilab") {
                    MIDIPortConnectSource(inputPort, source, nil)
                    DispatchQueue.main.async {
                        self.connectedDevice = deviceName
                    }
                    return
                }
            }
        }

        // Fallback: connect first available source
        if sourceCount > 0 {
            let source = MIDIGetSource(0)
            MIDIPortConnectSource(inputPort, source, nil)
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(source, kMIDIPropertyDisplayName, &name)
            let deviceName = (name?.takeRetainedValue() as String?) ?? "Unknown"
            DispatchQueue.main.async {
                self.connectedDevice = deviceName
            }
        }
    }

    private func handleMIDIEvents(_ eventList: UnsafePointer<MIDIEventList>) {
        let list = eventList.pointee
        var packet = list.packet

        for _ in 0..<list.numPackets {
            let word = packet.words.0

            let status = (word >> 16) & 0xF0
            let data1 = Int((word >> 8) & 0x7F)
            let data2 = Int(word & 0x7F)

            switch status {
            case 0x90 where data2 > 0:
                ringBuffer.pointee.write(.noteOn(note: data1, velocity: data2))
            case 0x80, 0x90: // note off, or note on with velocity 0
                ringBuffer.pointee.write(.noteOff(note: data1))
            case 0xB0: // CC
                ringBuffer.pointee.write(.cc(number: data1, value: data2))
            default:
                break
            }

            var current = packet
            packet = MIDIEventPacketNext(&current).pointee
        }
    }

    private func handleMIDINotification(_ notification: UnsafePointer<MIDINotification>) {
        if notification.pointee.messageID == .msgObjectAdded {
            connectToMiniLab()
        }
    }

    func stop() {
        MIDIPortDispose(inputPort)
        MIDIClientDispose(midiClient)
    }
}
```

**Step 2: Update GodEngine to own the ring buffer and drain in processBlock**

In `GodEngine.swift`, make these changes:

1. Add ring buffer property (after `voices`):
```swift
var midiRingBuffer = MIDIRingBuffer()
```

2. Add CC-to-layer mapping constant:
```swift
// MiniLab 3 knobs 1-8 default to CC 14-21
private static let ccToLayerOffset = 14
```

3. Replace `onPadHit` with an audio-thread-only version (no DispatchQueue):
```swift
private func handlePadHit(note: Int, velocity: Int) {
    guard let padIndex = padBank.padIndex(forNote: note),
          let sample = padBank.pads[padIndex].sample else { return }

    audioLayers[padIndex].addHit(at: audioPosition, velocity: velocity)
    audioLayers[padIndex].name = padBank.pads[padIndex].name

    let vel = Float(velocity) / 127.0 * audioLayers[padIndex].volume
    voices.append(Voice(sample: sample, velocity: vel, padIndex: padIndex))

    pendingTriggers[padIndex] = true
}
```

4. Add Note Off handler:
```swift
private func handleNoteOff(note: Int) {
    guard let padIndex = padBank.padIndex(forNote: note) else { return }
    guard !padBank.pads[padIndex].isOneShot else { return }
    // Stop all voices for this pad
    voices.removeAll { $0.padIndex == padIndex }
}
```

5. Add CC handler:
```swift
private func handleCC(number: Int, value: Int) {
    let layerIndex = number - Self.ccToLayerOffset
    guard layerIndex >= 0, layerIndex < 8 else { return }
    audioLayers[layerIndex].volume = Float(value) / 127.0
}
```

6. Add `pendingTriggers` array (alongside `pendingLevels`):
```swift
private var pendingTriggers: [Bool] = Array(repeating: false, count: 8)
```

7. At the **top** of `processBlock`, after the `guard audioIsPlaying` check, drain the ring buffer:
```swift
// Drain MIDI events from ring buffer
midiRingBuffer.drain { event in
    switch event {
    case .noteOn(let note, let velocity):
        handlePadHit(note: note, velocity: velocity)
    case .noteOff(let note):
        handleNoteOff(note: note)
    case .cc(let number, let value):
        handleCC(number: number, value: value)
    }
}
```

8. In the existing layer hit replay loop (lines 149-154), apply layer volume:
```swift
for hit in hits {
    if let sample = padBank.pads[layer.index].sample {
        let vel = Float(hit.velocity) / 127.0 * layer.volume
        voices.append(Voice(sample: sample, velocity: vel, padIndex: layer.index))
    }
}
```

9. Fix signal level detection (lines 180-195) to use `padIndex` instead of name matching:
```swift
for voice in voices where voice.padIndex >= 0 && voice.padIndex < 8 {
    let remaining = min(frameCount, voice.sample.data.count - voice.position)
    if remaining > 0 {
        let start = max(0, voice.position)
        let end = min(voice.sample.data.count, start + remaining)
        for j in start..<end {
            pendingLevels[voice.padIndex] = max(
                pendingLevels[voice.padIndex],
                abs(voice.sample.data[j] * voice.velocity)
            )
        }
    }
}
```

10. In the throttled UI update section (lines 221-234), add trigger sync and layer volume sync:
```swift
uiUpdateCounter += frameCount
if uiUpdateCounter >= 1323 {
    uiUpdateCounter = 0
    let pos = audioPosition
    let levels = pendingLevels
    let masterPeak = peak
    let triggers = pendingTriggers
    let layerVolumes = audioLayers.map { $0.volume }
    pendingLevels = Array(repeating: 0, count: 8)
    pendingTriggers = Array(repeating: false, count: 8)
    DispatchQueue.main.async {
        self.transport.position = pos
        self.channelSignalLevels = levels
        self.masterLevel = masterPeak
        for i in 0..<8 {
            if triggers[i] {
                self.channelTriggered[i] = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.channelTriggered[i] = false
                }
            }
            self.layers[i].volume = layerVolumes[i]
        }
    }
}
```

11. Remove the old `onPadHit` method entirely.

12. Update any code that creates `MIDIManager` to pass `&engine.midiRingBuffer` instead of `engine`. Search for `MIDIManager(engine:` in the codebase and update.

**Step 3: Run all tests**

Run: `cd /Users/brawny/god/GOD && swift test 2>&1 | tail -30`
Expected: All tests PASS.

**Step 4: Commit**

```bash
cd /Users/brawny/god
git add GOD/GOD/Engine/MIDIManager.swift GOD/GOD/Engine/GodEngine.swift
git commit -m "feat: wire lock-free ring buffer for thread-safe MIDI processing"
```

---

### Task 4: Integration tests for MIDI event handling

**Files:**
- Modify: `Tests/MIDITests.swift` — add integration tests

**Step 1: Add integration tests**

Append to `Tests/MIDITests.swift`:

```swift
@Test @MainActor func noteOnTriggersPadHit() {
    let engine = GodEngine()
    let sample = Sample(name: "kick", data: [Float](repeating: 0.5, count: 100), sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.togglePlay()

    // Simulate MIDI note on via ring buffer
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))

    // processBlock drains the ring buffer
    let _ = engine.processBlock(frameCount: 512)

    #expect(engine.voices.count >= 1)
    #expect(engine.voices.first?.padIndex == 0)
}

@Test @MainActor func noteOnOutOfRangeIgnored() {
    let engine = GodEngine()
    let sample = Sample(name: "kick", data: [Float](repeating: 0.5, count: 100), sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.togglePlay()

    engine.midiRingBuffer.write(.noteOn(note: 99, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)

    // No voice should be created for unmapped note
    let padVoices = engine.voices.filter { $0.padIndex >= 0 }
    #expect(padVoices.count == 0)
}

@Test @MainActor func noteOffIgnoredForOneShot() {
    let engine = GodEngine()
    let sample = Sample(name: "kick", data: [Float](repeating: 0.5, count: 44100), sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    // isOneShot is true by default
    engine.togglePlay()

    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)
    let voicesBefore = engine.voices.count

    engine.midiRingBuffer.write(.noteOff(note: 36))
    let _ = engine.processBlock(frameCount: 512)

    // Voice should still be there (one-shot ignores note off)
    #expect(engine.voices.count == voicesBefore)
}

@Test @MainActor func noteOffStopsHoldModeVoice() {
    let engine = GodEngine()
    let sample = Sample(name: "kick", data: [Float](repeating: 0.5, count: 44100), sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.padBank.pads[0].isOneShot = false
    engine.togglePlay()

    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)
    #expect(engine.voices.filter { $0.padIndex == 0 }.count >= 1)

    engine.midiRingBuffer.write(.noteOff(note: 36))
    let _ = engine.processBlock(frameCount: 512)

    // Voice should be removed (hold mode)
    #expect(engine.voices.filter { $0.padIndex == 0 }.count == 0)
}

@Test @MainActor func ccSetsLayerVolume() {
    let engine = GodEngine()
    engine.togglePlay()

    // CC 14 = layer 0, value 64 = 0.5
    engine.midiRingBuffer.write(.cc(number: 14, value: 64))
    let _ = engine.processBlock(frameCount: 512)

    // Check audio layer volume was set (access via a subsequent voice mix)
    // We verify by sending a note and checking the velocity is scaled
    let sample = Sample(name: "kick", data: [Float](repeating: 1.0, count: 100), sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 127))
    let _ = engine.processBlock(frameCount: 512)

    // Voice velocity should be scaled by layer volume (~0.5)
    if let voice = engine.voices.first(where: { $0.padIndex == 0 }) {
        #expect(voice.velocity < 0.6)
        #expect(voice.velocity > 0.4)
    } else {
        Issue.record("Expected voice for pad 0")
    }
}

@Test @MainActor func ccOutOfRangeIgnored() {
    let engine = GodEngine()
    engine.togglePlay()

    // CC 1 is not mapped to any layer
    engine.midiRingBuffer.write(.cc(number: 1, value: 127))
    let _ = engine.processBlock(frameCount: 512)

    // All layers should still have default volume
    // (We can't directly access audioLayers, but we can verify via behavior)
    let sample = Sample(name: "kick", data: [Float](repeating: 1.0, count: 100), sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 127))
    let _ = engine.processBlock(frameCount: 512)

    if let voice = engine.voices.first(where: { $0.padIndex == 0 }) {
        #expect(voice.velocity > 0.99)  // full volume, unaffected
    } else {
        Issue.record("Expected voice for pad 0")
    }
}
```

**Step 2: Run tests**

Run: `cd /Users/brawny/god/GOD && swift test --filter MIDITests 2>&1 | tail -30`
Expected: All tests PASS.

**Step 3: Run full test suite**

Run: `cd /Users/brawny/god/GOD && swift test 2>&1 | tail -20`
Expected: All tests PASS.

**Step 4: Commit**

```bash
cd /Users/brawny/god
git add GOD/Tests/MIDITests.swift
git commit -m "test: add MIDI integration tests for note on/off, CC, and ring buffer"
```

---

### Task 5: Update MIDIManager initialization in app layer

**Files:**
- Search for `MIDIManager(engine:` in the codebase and update to `MIDIManager(ringBuffer:)`

**Step 1: Find all MIDIManager creation sites**

Run: `grep -rn "MIDIManager(" GOD/GOD/`

**Step 2: Update each call site**

Replace `MIDIManager(engine: engine)` with:
```swift
MIDIManager(ringBuffer: &engine.midiRingBuffer)
```

Note: Since `midiRingBuffer` is a var on `GodEngine`, we need to use `withUnsafeMutablePointer` or store it differently. The simplest approach: make the ring buffer a class-level allocation.

If the ring buffer is used as `UnsafeMutablePointer`, change GodEngine to:
```swift
let midiRingBufferPtr: UnsafeMutablePointer<MIDIRingBuffer> = {
    let ptr = UnsafeMutablePointer<MIDIRingBuffer>.allocate(capacity: 1)
    ptr.initialize(to: MIDIRingBuffer())
    return ptr
}()
```

And update `processBlock` to drain from `midiRingBufferPtr.pointee` and MIDIManager init to take `midiRingBufferPtr`.

Alternatively, keep it simple: make `MIDIRingBuffer` a class instead of a struct, avoiding pointer gymnastics entirely. The ring buffer is inherently shared mutable state, so reference semantics are appropriate.

**Decision:** Make `MIDIRingBuffer` a final class. Update Task 1's implementation accordingly if not already a class.

**Step 3: Run all tests**

Run: `cd /Users/brawny/god/GOD && swift test 2>&1 | tail -20`
Expected: All tests PASS.

**Step 4: Build and verify**

Run: `cd /Users/brawny/god/GOD && swift build 2>&1 | tail -10`
Expected: Build succeeds.

**Step 5: Commit**

```bash
cd /Users/brawny/god
git add GOD/GOD/
git commit -m "feat: update MIDIManager to use shared ring buffer"
```

---

### Task 6: Sync layer hits from audio thread to UI layers

**Context:** After Task 3, `handlePadHit` only writes to `audioLayers`, not to `layers` (the UI copy). The UI needs to see hits for display purposes. Add hit sync in the throttled UI update.

**Files:**
- Modify: `GOD/GOD/Engine/GodEngine.swift` — sync hits from audioLayers to layers in UI update

**Step 1: Add pending hits tracking**

Add to GodEngine (alongside `pendingTriggers`):
```swift
private var pendingHits: [(padIndex: Int, position: Int, velocity: Int)] = []
```

In `handlePadHit`, after `audioLayers[padIndex].addHit(...)`:
```swift
pendingHits.append((padIndex: padIndex, position: audioPosition, velocity: velocity))
```

In the throttled UI update, capture and clear pendingHits, then apply:
```swift
let hits = pendingHits
pendingHits.removeAll()
// ...inside DispatchQueue.main.async:
for hit in hits {
    self.layers[hit.padIndex].addHit(at: hit.position, velocity: hit.velocity)
    self.layers[hit.padIndex].name = self.padBank.pads[hit.padIndex].name
}
```

**Step 2: Run all tests**

Run: `cd /Users/brawny/god/GOD && swift test 2>&1 | tail -20`
Expected: All tests PASS.

**Step 3: Commit**

```bash
cd /Users/brawny/god
git add GOD/GOD/Engine/GodEngine.swift
git commit -m "feat: sync MIDI hits from audio thread to UI layers"
```

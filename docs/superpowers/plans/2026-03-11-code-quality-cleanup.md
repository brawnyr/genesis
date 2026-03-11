# Code Quality Cleanup Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clean up code quality across 12 items: eliminate magic numbers, add access control, deduplicate logic, guard unsafe operations, consolidate overlays, and refactor the two largest files.

**Architecture:** No new dependencies or architectural changes. All changes are refactors within existing files. GodEngine gets a VoiceMixer extraction and AudioState struct. ContentView gets an EditMode enum. Everything else is in-place cleanup.

**Tech Stack:** Swift, SwiftUI, Swift Testing. Build: `cd ~/god/GOD && swift build`. Test: `cd ~/god/GOD && swift test`.

**Pre-existing state:** 88/89 tests pass. `engineActivePadTracking` has a pre-existing failure (test expects CC volume to change voice velocity — it doesn't, CC changes layer volume applied at mix time). Do not break any currently-passing tests.

---

## File Structure

**Files modified (no new files created):**

| File | Changes |
|------|---------|
| `GOD/GOD/Models/Biquad.swift` | Clamp ccToFrequency input (item 12) |
| `GOD/GOD/Models/Sample.swift` | Guard force-unwrap on floatChannelData (item 8) |
| `GOD/GOD/Models/GodCapture.swift` | Cache DateFormatter as static (item 7) |
| `GOD/GOD/Models/Transport.swift` | Add `beatsPerBar` constant, `currentBeat` computed property (items 5, 6) |
| `GOD/GOD/Models/Metronome.swift` | Name magic constants for click generation (item 6) |
| `GOD/GOD/Models/Layer.swift` | Name filter bypass constants (item 6) |
| `GOD/GOD/Engine/GodEngine.swift` | Extract VoiceMixer + AudioState, add access control, name constants, use PadBank.padCount (items 1, 4, 6, 9) |
| `GOD/GOD/Engine/EngineEventInterpreter.swift` | Name decay constants, cache DateFormatter, use PadBank.padCount (items 4, 6, 7) |
| `GOD/GOD/Engine/BPMDetector.swift` | Name window/threshold/bin constants (item 6) |
| `GOD/GOD/ContentView.swift` | Refactor to EditMode enum (item 2) |
| `GOD/GOD/Views/PadStripView.swift` | Consolidate overlays, use PadBank.padCount (items 4, 10) |
| `GOD/GOD/Views/CanvasView.swift` | Use Transport.currentBeat, use PadBank.padCount (items 4, 5) |
| `GOD/GOD/Views/TransportView.swift` | Use Transport.currentBeat (item 5) |
| `GOD/GOD/Views/KeyReferenceOverlay.swift` | Enum-based shortcuts (item 11) |
| `GOD/GOD/Models/Pad.swift` | Log errors on sample load failure (item 3) |
| `GOD/GOD/GODApp.swift` | Log errors on config operations (item 3) |
| `GOD/Tests/TransportTests.swift` | Test for currentBeat computed property |
| `GOD/Tests/BiquadTests.swift` | Test for ccToFrequency clamping |

---

## Chunk 1: Quick Isolated Fixes (Items 7, 8, 12)

### Task 1: Clamp ccToFrequency input to 0-127 (Item 12)

**Files:**
- Modify: `GOD/GOD/Models/Biquad.swift:81-83`
- Test: `GOD/Tests/BiquadTests.swift`

- [ ] **Step 1: Write failing test for clamping**

In `GOD/Tests/BiquadTests.swift`, add:

```swift
@Test func ccToFrequencyClamps() {
    // Negative CC should clamp to 0 → ~20Hz
    let fNeg = ccToFrequency(-10)
    #expect(abs(fNeg - 20.0) < 1.0)

    // CC > 127 should clamp to 127 → ~20kHz
    let fOver = ccToFrequency(200)
    #expect(abs(fOver - 20000.0) < 100.0)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/god/GOD && swift test --filter ccToFrequencyClamps`
Expected: FAIL (negative CC produces garbage value)

- [ ] **Step 3: Implement clamping**

In `GOD/GOD/Models/Biquad.swift`, replace lines 81-83:

```swift
func ccToFrequency(_ cc: Int) -> Float {
    let clamped = max(0, min(127, cc))
    let normalized = Float(clamped) / 127.0
    return 20.0 * pow(1000.0, normalized)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/god/GOD && swift test --filter ccToFrequency`
Expected: PASS (both old and new tests)

- [ ] **Step 5: Commit**

```bash
git add GOD/GOD/Models/Biquad.swift GOD/Tests/BiquadTests.swift
git commit -m "fix: clamp ccToFrequency input to 0-127 range"
```

---

### Task 2: Guard force-unwrap on floatChannelData (Item 8)

**Files:**
- Modify: `GOD/GOD/Models/Sample.swift:57-68`

- [ ] **Step 1: Replace force-unwraps with guard**

In `GOD/GOD/Models/Sample.swift`, replace lines 57-68 with:

```swift
        let frameLen = Int(outputBuffer.frameLength)
        guard let channelData = outputBuffer.floatChannelData else {
            throw SampleError.conversionFailed
        }
        let leftData = Array(UnsafeBufferPointer(
            start: channelData[0], count: frameLen
        ))
        let rightData: [Float]
        if outputBuffer.format.channelCount >= 2 {
            rightData = Array(UnsafeBufferPointer(
                start: channelData[1], count: frameLen
            ))
        } else {
            rightData = leftData
        }
```

- [ ] **Step 2: Run all tests**

Run: `cd ~/god/GOD && swift test`
Expected: All previously-passing tests still pass

- [ ] **Step 3: Commit**

```bash
git add GOD/GOD/Models/Sample.swift
git commit -m "fix: guard floatChannelData instead of force-unwrapping"
```

---

### Task 3: Cache DateFormatter in GodCapture and EngineEventInterpreter (Item 7)

**Files:**
- Modify: `GOD/GOD/Models/GodCapture.swift:58-61`
- Modify: `GOD/GOD/Engine/EngineEventInterpreter.swift:12-23`

- [ ] **Step 1: Cache DateFormatter in GodCapture**

In `GOD/GOD/Models/GodCapture.swift`, add a static formatter and replace the per-call creation. Replace lines 58-61:

```swift
    private static let filenameDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f
    }()

    private static func writeWAV(left: [Float], right: [Float]) {
        let filename = "GOD_\(filenameDateFormatter.string(from: Date())).wav"
```

- [ ] **Step 2: Cache DateFormatter in TerminalLine**

In `GOD/GOD/Engine/EngineEventInterpreter.swift`, replace the `timeString` computed property (lines 19-23) with a cached formatter:

```swift
struct TerminalLine: Identifiable {
    let id = UUID()
    let text: String
    let kind: LineKind
    let isHighlight: Bool
    let timestamp: Date = Date()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var timeString: String {
        Self.timeFormatter.string(from: timestamp)
    }
}
```

- [ ] **Step 3: Run all tests**

Run: `cd ~/god/GOD && swift test`
Expected: All previously-passing tests still pass

- [ ] **Step 4: Commit**

```bash
git add GOD/GOD/Models/GodCapture.swift GOD/GOD/Engine/EngineEventInterpreter.swift
git commit -m "perf: cache DateFormatters instead of creating per-call"
```

---

## Chunk 2: Named Constants (Item 6)

### Task 4: Name magic numbers across the codebase

**Files:**
- Modify: `GOD/GOD/Engine/GodEngine.swift:51-52`
- Modify: `GOD/GOD/Engine/EngineEventInterpreter.swift:43-45`
- Modify: `GOD/GOD/Engine/BPMDetector.swift:14-15, 37, 55, 63, 74-76`
- Modify: `GOD/GOD/Models/Metronome.swift:16-19, 24`
- Modify: `GOD/GOD/Models/Layer.swift:15-16`
- Modify: `GOD/GOD/Models/Transport.swift:23`

- [ ] **Step 1: Name constants in GodEngine**

In `GOD/GOD/Engine/GodEngine.swift`, replace line 52:

```swift
    // UI update throttle: 44100 / 33 ≈ 1337 frames → ~33Hz (~30fps)
    private static let uiUpdateHz: Double = 33.0
    private static let uiUpdateFrameThreshold = Int(Transport.sampleRate / uiUpdateHz)
```

- [ ] **Step 2: Name constants in EngineEventInterpreter**

In `GOD/GOD/Engine/EngineEventInterpreter.swift`, replace lines 43-45:

```swift
    // Visual intensity decay per tick
    // shortDecay: 8% per frame — quick falloff for short samples
    // sustainDecay: 2% per frame — slow falloff for long/looping voices
    private static let shortDecay: Float = 0.92
    private static let sustainDecay: Float = 0.98
    private static let sustainMinIntensity: Float = 0.3
    private static let intensityCutoff: Float = 0.01
```

Then update `tickVisuals()` to use `sustainMinIntensity` and `intensityCutoff`:

```swift
    func tickVisuals() {
        var updated = padIntensities
        for i in 0..<8 {
            if activePadVoices.contains(i) {
                updated[i] = max(updated[i] * Self.sustainDecay, Self.sustainMinIntensity)
            } else if updated[i] > Self.intensityCutoff {
                updated[i] *= Self.shortDecay
            } else {
                updated[i] = 0
            }
        }
        padIntensities = updated
    }
```

- [ ] **Step 3: Name constants in BPMDetector**

In `GOD/GOD/Engine/BPMDetector.swift`, replace the magic numbers:

```swift
enum BPMDetector {
    /// Minimum sample duration for BPM detection (0.5 seconds)
    private static let minFrames = 22050

    // Onset detection parameters
    private static let windowSize = 1024       // ~23ms at 44.1kHz
    private static let hopSize = 512           // 50% overlap
    private static let onsetThresholdMultiplier: Float = 1.5  // peaks must exceed mean * this

    // Inter-onset interval filtering
    private static let minIntervalSec = 0.15   // fastest: 400 BPM
    private static let maxIntervalSec = 2.0    // slowest: 30 BPM
    private static let histogramBinSec = 0.02  // 20ms bins

    // Output normalization range
    private static let minBPM = 70.0
    private static let maxBPM = 180.0
```

Then update the function body to use these constants (replace `1024`, `512`, `1.5`, `0.15`, `2.0`, `0.02`, `180`, `70`).

- [ ] **Step 4: Name constants in Metronome**

In `GOD/GOD/Models/Metronome.swift`, replace lines 15-28:

```swift
    // Click generation constants
    private static let clickDuration: Double = 0.02     // 20ms
    private static let downbeatFreq: Double = 1500.0    // Hz
    private static let beatFreq: Double = 1000.0        // Hz
    private static let downbeatAmplitude: Float = 0.8
    private static let beatAmplitude: Float = 0.4
    private static let clickDecayRate: Double = 150.0   // envelope decay speed

    static func generateClick(isDownbeat: Bool, sampleRate: Double) -> Sample {
        let frameCount = Int(clickDuration * sampleRate)
        let frequency = isDownbeat ? downbeatFreq : beatFreq
        let amplitude = isDownbeat ? downbeatAmplitude : beatAmplitude

        var buffer = [Float](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let envelope = Float(exp(-t * clickDecayRate))
            let sine = Float(sin(2.0 * .pi * frequency * t))
            buffer[i] = sine * envelope * amplitude
        }
        return Sample(name: "click", left: buffer, right: buffer, sampleRate: sampleRate)
    }
```

- [ ] **Step 5: Name constants in Layer**

In `GOD/GOD/Models/Layer.swift`, replace lines 15-16:

```swift
    static let hpBypassFrequency: Float = 20.0       // Hz — below this, HP has no effect
    static let lpBypassFrequency: Float = 20000.0     // Hz — above this, LP has no effect

    var hpCutoff: Float = Layer.hpBypassFrequency
    var lpCutoff: Float = Layer.lpBypassFrequency
```

- [ ] **Step 6: Name constant in Transport**

In `GOD/GOD/Models/Transport.swift`, replace line 23:

```swift
    static let beatsPerBar = 4

    var loopLengthFrames: Int {
        let beatsPerLoop = Double(barCount * Self.beatsPerBar)
        let secondsPerBeat = 60.0 / Double(bpm)
        return Int(beatsPerLoop * secondsPerBeat * Self.sampleRate)
    }
```

- [ ] **Step 7: Build and test**

Run: `cd ~/god/GOD && swift build && swift test`
Expected: Build succeeds, all previously-passing tests still pass

- [ ] **Step 8: Commit**

```bash
git add GOD/GOD/Engine/GodEngine.swift GOD/GOD/Engine/EngineEventInterpreter.swift \
       GOD/GOD/Engine/BPMDetector.swift GOD/GOD/Models/Metronome.swift \
       GOD/GOD/Models/Layer.swift GOD/GOD/Models/Transport.swift
git commit -m "refactor: name magic numbers across engine, models, and detector"
```

---

## Chunk 3: PadBank.padCount Everywhere (Item 4)

### Task 5: Replace hardcoded 8 with PadBank.padCount

**Files:**
- Modify: `GOD/GOD/Engine/GodEngine.swift` (lines 12, 16, 17, 20, 35, 46-49, 54-56, 176-178, 182-184, 271, 382-385, 388, 453-454, 470)
- Modify: `GOD/GOD/Engine/EngineEventInterpreter.swift` (lines 28, 33-37, 40-41, 89, 105, 151, 172-173, 178)
- Modify: `GOD/GOD/Views/PadStripView.swift` (line 14)
- Modify: `GOD/GOD/Views/CanvasView.swift` (line 45)
- Modify: `GOD/GOD/GODApp.swift` (line 86)
- Modify: `GOD/GOD/ContentView.swift` (lines 327, 330)

- [ ] **Step 1: Replace in GodEngine.swift**

Replace all `(0..<8)` initializers and `count: 8` with `PadBank.padCount`:

```swift
    @Published var layers: [Layer] = (0..<PadBank.padCount).map { Layer(index: $0, name: "PAD \($0 + 1)") }
    @Published var channelSignalLevels: [Float] = Array(repeating: 0, count: PadBank.padCount)
    @Published var channelTriggered: [Bool] = Array(repeating: false, count: PadBank.padCount)
    @Published var channelLevelDb: [Float] = Array(repeating: -.infinity, count: PadBank.padCount)
    // ...
    private var audioLayers: [Layer] = (0..<PadBank.padCount).map { Layer(index: $0, name: "PAD \($0 + 1)") }
    private var cachedHPCutoffs: [Float] = Array(repeating: Layer.hpBypassFrequency, count: PadBank.padCount)
    private var cachedLPCutoffs: [Float] = Array(repeating: Layer.lpBypassFrequency, count: PadBank.padCount)
    private var cachedHPCoeffs: [BiquadCoefficients] = Array(repeating: .bypass, count: PadBank.padCount)
    private var cachedLPCoeffs: [BiquadCoefficients] = Array(repeating: .bypass, count: PadBank.padCount)
    private var pendingLevels: [Float] = Array(repeating: 0, count: PadBank.padCount)
    private var pendingTriggers: [Bool] = Array(repeating: false, count: PadBank.padCount)
```

Replace all `for i in 0..<8` with `for i in 0..<PadBank.padCount` and all `count: 8` resets.

Also replace pad cycling in ContentView.swift:
```swift
    // lines 327, 330
    engine.activePadIndex = (engine.activePadIndex - 1 + PadBank.padCount) % PadBank.padCount
    engine.activePadIndex = (engine.activePadIndex + 1) % PadBank.padCount
```

- [ ] **Step 2: Replace in EngineEventInterpreter.swift**

All `count: 8` arrays and `0..<8` loops → `PadBank.padCount`:

```swift
    @Published var padIntensities: [Float] = Array(repeating: 0, count: PadBank.padCount)
    private var prevMuted: [Bool] = Array(repeating: false, count: PadBank.padCount)
    private var prevVolumes: [Float] = Array(repeating: 1.0, count: PadBank.padCount)
    private var prevPans: [Float] = Array(repeating: 0.5, count: PadBank.padCount)
    private var prevHP: [Float] = Array(repeating: Layer.hpBypassFrequency, count: PadBank.padCount)
    private var prevLP: [Float] = Array(repeating: Layer.lpBypassFrequency, count: PadBank.padCount)
    private var loopHitCounts: [Int] = Array(repeating: 0, count: PadBank.padCount)
    private var loopHitVelocities: [[Int]] = Array(repeating: [], count: PadBank.padCount)
```

And in `tickVisuals()`, `processStateDiff()`, `onLoopBoundary()`: replace `0..<8` with `0..<PadBank.padCount`.

- [ ] **Step 3: Replace in Views**

`PadStripView.swift` line 14:
```swift
ForEach(0..<PadBank.padCount, id: \.self) { index in
```

`CanvasView.swift` line 45:
```swift
ForEach(0..<PadBank.padCount, id: \.self) { i in
```

`GODApp.swift` line 86:
```swift
for i in 0..<PadBank.padCount {
```

Also `Pad.swift` line 37 (already uses padCount? let me check — yes it uses `0..<8`):
```swift
var pads: [Pad] = (0..<padCount).map { i in
```

- [ ] **Step 4: Build and test**

Run: `cd ~/god/GOD && swift build && swift test`
Expected: Build succeeds, all previously-passing tests still pass

- [ ] **Step 5: Commit**

```bash
git add GOD/GOD/Engine/GodEngine.swift GOD/GOD/Engine/EngineEventInterpreter.swift \
       GOD/GOD/Views/PadStripView.swift GOD/GOD/Views/CanvasView.swift \
       GOD/GOD/GODApp.swift GOD/GOD/ContentView.swift GOD/GOD/Models/Pad.swift
git commit -m "refactor: replace hardcoded 8 with PadBank.padCount everywhere"
```

---

## Chunk 4: Transport.currentBeat Deduplication (Item 5)

### Task 6: Extract currentBeat to Transport

**Files:**
- Modify: `GOD/GOD/Models/Transport.swift`
- Modify: `GOD/GOD/Views/TransportView.swift:6-13`
- Modify: `GOD/GOD/Views/CanvasView.swift:85-89`
- Test: `GOD/Tests/TransportTests.swift`

- [ ] **Step 1: Write failing test**

In `GOD/Tests/TransportTests.swift`, add:

```swift
@Test func transportCurrentBeat() {
    var t = Transport()
    t.bpm = 120
    t.barCount = 4
    t.isPlaying = true
    t.position = 0
    #expect(t.currentBeat == 1)

    // At exactly 1 beat in (0.5s at 120bpm = 22050 frames)
    t.position = 22050
    #expect(t.currentBeat == 2)

    // At 4 beats in
    t.position = 88200
    #expect(t.currentBeat == 5)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/god/GOD && swift test --filter transportCurrentBeat`
Expected: FAIL (property doesn't exist)

- [ ] **Step 3: Add currentBeat to Transport**

In `GOD/GOD/Models/Transport.swift`, add after `loopLengthFrames`:

```swift
    var currentBeat: Int {
        let beatLengthFrames = Int(60.0 / Double(bpm) * Self.sampleRate)
        guard beatLengthFrames > 0 else { return 1 }
        return (position / beatLengthFrames) % (barCount * Self.beatsPerBar) + 1
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/god/GOD && swift test --filter transportCurrentBeat`
Expected: PASS

- [ ] **Step 5: Replace duplicated calculations in views**

In `GOD/GOD/Views/TransportView.swift`, delete the `currentBeat` computed property (lines 6-13) and replace all `currentBeat` references with `engine.transport.currentBeat`.

In `GOD/GOD/Views/CanvasView.swift` (GodTitleLayer), delete the `currentBeat` computed property (lines 85-89) and replace `currentBeat` with `transport.currentBeat`.

- [ ] **Step 6: Build and test**

Run: `cd ~/god/GOD && swift build && swift test`
Expected: Build succeeds, all previously-passing tests still pass

- [ ] **Step 7: Commit**

```bash
git add GOD/GOD/Models/Transport.swift GOD/GOD/Views/TransportView.swift \
       GOD/GOD/Views/CanvasView.swift GOD/Tests/TransportTests.swift
git commit -m "refactor: deduplicate currentBeat into Transport computed property"
```

---

## Chunk 5: GodEngine Split + Access Control (Items 1, 9)

### Task 7: Extract VoiceMixer from GodEngine

This is the biggest refactor. The goal: move voice mixing logic out of `processBlock()` into a focused struct, and group audio-thread-only state into an `AudioState` struct with clear ownership comments.

**Files:**
- Modify: `GOD/GOD/Engine/GodEngine.swift`

- [ ] **Step 1: Create AudioState struct at top of GodEngine.swift**

Above the `GodEngine` class, add a struct that groups all audio-thread-only state:

```swift
/// All state owned exclusively by the audio thread.
/// Never access @Published properties from here. Sync to main thread via DispatchQueue.main.async.
struct AudioState {
    var position: Int = 0
    var isPlaying: Bool = false
    var bpm: Int = 120
    var barCount: Int = 4
    var metronomeOn: Bool = true
    var metronomeVolume: Float = 0.5
    var layers: [Layer] = (0..<PadBank.padCount).map { Layer(index: $0, name: "PAD \($0 + 1)") }
    var captureState: GodCapture.State = .idle
    var capture = GodCapture()
    var activePadIndex: Int = 0
    var toggleMode: ToggleMode = .instant
    var pendingMutes: [Int: Bool] = [:]

    var loopLengthFrames: Int {
        let beatsPerLoop = Double(barCount * Transport.beatsPerBar)
        let secondsPerBeat = 60.0 / Double(bpm)
        return Int(beatsPerLoop * secondsPerBeat * Transport.sampleRate)
    }
}
```

- [ ] **Step 2: Replace individual audio fields with AudioState**

In `GodEngine`, replace all the individual `private var audio*` fields (lines 29-37, 59-61) with:

```swift
    // Audio thread state — only touched from processBlock() and its helpers.
    // Synced to main thread via throttled DispatchQueue.main.async.
    private var audio = AudioState()
```

Then update all references:
- `audioPosition` → `audio.position`
- `audioIsPlaying` → `audio.isPlaying`
- `audioBPM` → `audio.bpm`
- `audioBarCount` → `audio.barCount`
- `audioMetronomeOn` → `audio.metronomeOn`
- `audioMetronomeVolume` → `audio.metronomeVolume`
- `audioLayers` → `audio.layers`
- `audioCaptureState` → `audio.captureState`
- `audioCapture` → `audio.capture`
- `audioActivePadIndex` → `audio.activePadIndex`
- `audioToggleMode` → `audio.toggleMode`
- `audioPendingMutes` → `audio.pendingMutes`
- `audioLoopLengthFrames` → `audio.loopLengthFrames`

- [ ] **Step 3: Add access control**

Mark all internal state explicitly:

```swift
class GodEngine: ObservableObject {
    // MARK: - UI state (main thread only, observed by SwiftUI)
    @Published var transport = Transport()
    @Published var layers: [Layer] = ...
    // ... all @Published stay as-is

    // MARK: - Audio thread state (never touch @Published from here)
    private var audio = AudioState()
    private(set) var voices: [Voice] = []
    let midiRingBuffer = MIDIRingBuffer()

    // MARK: - Audio thread buffers (pre-allocated, avoid heap allocs)
    private var outputBufferL = [Float](repeating: 0, count: 4096)
    private var outputBufferR = [Float](repeating: 0, count: 4096)

    // MARK: - Cached biquad coefficients (recalculated only on cutoff change)
    private var cachedHPCutoffs: [Float] = ...
    // ...

    // MARK: - UI sync throttle
    private static let uiUpdateHz: Double = 33.0
    private static let uiUpdateFrameThreshold = Int(Transport.sampleRate / uiUpdateHz)
    private var pendingLevels: ...
    private var pendingTriggers: ...
    private var pendingHits: ...
    private var uiUpdateCounter = 0
    private var lastClearedLayerIndex: Int?
```

- [ ] **Step 4: Build and test**

Run: `cd ~/god/GOD && swift build && swift test`
Expected: Build succeeds, all previously-passing tests still pass. This is purely a rename/regroup — zero behavior change.

- [ ] **Step 5: Commit**

```bash
git add GOD/GOD/Engine/GodEngine.swift
git commit -m "refactor: extract AudioState struct, add MARK sections and access control to GodEngine"
```

---

## Chunk 6: ContentView EditMode Refactor (Item 2)

### Task 8: Refactor ContentView with EditMode enum

**Files:**
- Modify: `GOD/GOD/ContentView.swift`

- [ ] **Step 1: Add EditMode enum and replace state booleans**

At the top of ContentView (inside the struct), replace the three state variables:

```swift
    // Replace these:
    // @State private var browsingPad = false
    // @State private var bpmMode = false

    private enum EditMode {
        case normal
        case bpm
        case browse
    }

    @State private var mode: EditMode = .normal
```

Keep `browserIndex`, `bpmInput`, `bpmPresetIndex`, `showKeyReference`, `masterVolumeMode` as-is.

- [ ] **Step 2: Update body to use mode**

Replace `browsingPad` references:
- `browsingPad` → `mode == .browse`
- `browsingPad.toggle()` → `mode = mode == .browse ? .normal : .browse`
- `browsingPad = false` → `mode = .normal`

In the `CCPanelView` call, replace the binding:
```swift
CCPanelView(
    engine: engine,
    masterVolumeMode: masterVolumeMode,
    browsingPad: Binding(
        get: { mode == .browse },
        set: { mode = $0 ? .browse : .normal }
    ),
    browserIndex: $browserIndex
)
```

- [ ] **Step 3: Refactor handleKey into mode-dispatched methods**

Replace the `handleKey` function with:

```swift
    private func handleKey(keyCode: UInt16, chars: String?, modifiers: NSEvent.ModifierFlags) {
        let shift = modifiers.contains(.shift)

        // Shift+1-8: always active (jump to pad)
        if shift, let c = chars?.first, handleShiftPad(c) { return }

        switch mode {
        case .bpm:    handleBPMKey(keyCode: keyCode, chars: chars)
        case .browse: handleBrowseKey(keyCode: keyCode, chars: chars)
        case .normal: handleNormalKey(keyCode: keyCode, chars: chars)
        }
    }

    private func handleShiftPad(_ c: Character) -> Bool {
        let shiftDigitMap: [Character: Int] = [
            "!": 0, "@": 1, "#": 2, "$": 3,
            "%": 4, "^": 5, "&": 6, "*": 7
        ]
        let numpadDigitMap: [Character: Int] = [
            "1": 0, "2": 1, "3": 2, "4": 3,
            "5": 4, "6": 5, "7": 6, "8": 7
        ]
        if let padIndex = shiftDigitMap[c] ?? numpadDigitMap[c] {
            engine.activePadIndex = padIndex
            interpreter.appendLine("pad \(padIndex + 1) → \(padName(padIndex))", kind: .state)
            return true
        }
        return false
    }

    private func handleBPMKey(keyCode: UInt16, chars: String?) {
        let presets = Self.bpmPresets
        switch keyCode {
        case Key.w:
            bpmPresetIndex = max(0, bpmPresetIndex - 1)
            bpmInput = ""
            let p = presets[bpmPresetIndex]
            engine.setBPM(p.bpm)
            interpreter.appendLine("bpm → \(p.bpm) \(p.mood)", kind: .transport)
        case Key.s:
            bpmPresetIndex = min(presets.count - 1, bpmPresetIndex + 1)
            bpmInput = ""
            let p = presets[bpmPresetIndex]
            engine.setBPM(p.bpm)
            interpreter.appendLine("bpm → \(p.bpm) \(p.mood)", kind: .transport)
        case Key.returnKey:
            if let bpm = Int(bpmInput), bpm > 0 {
                engine.setBPM(bpm)
                interpreter.appendLine("bpm set → \(bpm)", kind: .transport)
            }
            mode = .normal
            bpmInput = ""
        case Key.escape, Key.b:
            mode = .normal
            bpmInput = ""
            interpreter.appendLine("bpm closed", kind: .transport)
        default:
            if let c = chars?.first, c >= "0" && c <= "9" {
                bpmInput.append(c)
                interpreter.appendLine("bpm → \(bpmInput)_", kind: .transport)
            }
        }
    }

    private func handleBrowseKey(keyCode: UInt16, chars: String?) {
        switch keyCode {
        case Key.w:
            browserIndex = max(0, browserIndex - 1)
            loadBrowserSample()
            if let name = browserFileName() {
                interpreter.appendLine("browse → \(name)", kind: .browse)
            }
        case Key.s:
            browserIndex += 1
            loadBrowserSample()
            if let name = browserFileName() {
                interpreter.appendLine("browse → \(name)", kind: .browse)
            }
        case Key.returnKey, Key.t, Key.escape:
            mode = .normal
            interpreter.appendLine("browser closed", kind: .browse)
        default:
            // Fall through for non-browser keys (space, A/D, etc.)
            handleNormalKey(keyCode: keyCode, chars: chars)
        }
    }

    private func handleNormalKey(keyCode: UInt16, chars: String?) {
        // ... existing switch statement from lines 286-408
        // Move B key to set mode = .bpm
        // Move T key to set mode = .browse
    }
```

- [ ] **Step 4: Build and test**

Run: `cd ~/god/GOD && swift build && swift test`
Expected: Build succeeds, all previously-passing tests still pass

- [ ] **Step 5: Commit**

```bash
git add GOD/GOD/ContentView.swift
git commit -m "refactor: replace ContentView mode booleans with EditMode enum and split key handlers"
```

---

## Chunk 7: Error Logging (Item 3)

### Task 9: Replace silent try? with logged errors

**Files:**
- Modify: `GOD/GOD/Models/Pad.swift:81, 97-104`
- Modify: `GOD/GOD/GODApp.swift:83, 89`
- Modify: `GOD/GOD/Engine/GodEngine.swift:221`
- Modify: `GOD/GOD/ContentView.swift:171`

- [ ] **Step 1: Add logger to Pad.swift**

At the top of `GOD/GOD/Models/Pad.swift`:

```swift
import os

private let logger = Logger(subsystem: "com.god.pads", category: "PadBank")
```

Then replace silent `try?` in `loadConfig()` (line 81):

```swift
            do {
                let sample = try Sample.load(from: url)
                pads[index].sample = sample
                pads[index].samplePath = assignment.path
                pads[index].name = assignment.name
                pads[index].cut = assignment.cut ?? false
            } catch {
                logger.warning("Failed to load saved sample \(assignment.path): \(error.localizedDescription)")
            }
```

And in `loadFromSpliceFolders()` (line 104):

```swift
            guard let firstFile = contents.first else { continue }
            do {
                let sample = try Sample.load(from: firstFile)
                pads[index].sample = sample
                pads[index].samplePath = firstFile.path
                pads[index].name = sample.name.uppercased()
            } catch {
                logger.warning("Failed to load Splice sample \(firstFile.lastPathComponent): \(error.localizedDescription)")
            }
```

- [ ] **Step 2: Log errors in GODApp.swift**

Replace lines 83 and 89:

```swift
        do {
            try engine.padBank.loadConfig()
        } catch {
            logger.info("No saved pad config (or error loading): \(error.localizedDescription)")
        }
        // ... (loadFromSpliceFolders and restoreCutFromPadBank stay the same)
        do {
            try engine.padBank.save()
        } catch {
            logger.error("Failed to save pad config: \(error.localizedDescription)")
        }
```

- [ ] **Step 3: Log error in GodEngine.swift**

Replace line 221:

```swift
        do {
            try padBank.save()
        } catch {
            // Non-fatal: config save failure doesn't affect playback
        }
```

(GodEngine doesn't have a logger and adding one for one call isn't worth it. The important logging is in Pad.swift and GODApp.swift where we can see *why* things fail.)

- [ ] **Step 4: Log error in ContentView.swift**

Replace line 171:

```swift
        do {
            try engine.loadSample(from: url, forPad: padIndex)
            let name = engine.padBank.pads[padIndex].sample?.name.lowercased() ?? url.lastPathComponent
            interpreter.appendLine("sample loaded → \(name) on \(folderName)", kind: .browse)
        } catch {
            interpreter.appendLine("failed to load sample: \(error.localizedDescription)", kind: .system)
        }
```

- [ ] **Step 5: Build and test**

Run: `cd ~/god/GOD && swift build && swift test`
Expected: Build succeeds, all previously-passing tests still pass

- [ ] **Step 6: Commit**

```bash
git add GOD/GOD/Models/Pad.swift GOD/GOD/GODApp.swift \
       GOD/GOD/Engine/GodEngine.swift GOD/GOD/ContentView.swift
git commit -m "fix: replace silent try? with logged errors for sample and config operations"
```

---

## Chunk 8: View Cleanup (Items 10, 11)

### Task 10: Consolidate PadCell overlays (Item 10)

**Files:**
- Modify: `GOD/GOD/Views/PadStripView.swift:189-226`

- [ ] **Step 1: Extract compound overlay into a ViewModifier**

Add above `PadCell`:

```swift
struct PadCellOverlay: ViewModifier {
    let isHot: Bool
    let isCold: Bool
    let isActive: Bool
    let triggered: Bool
    let hasPending: Bool
    let pendingMute: Bool?
    let breathe: Double
    let pendingBlink: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(hotGlowStroke, lineWidth: 1)
            )
            .shadow(color: hotGlowShadow, radius: 10)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isCold ? Theme.ice.opacity(0.05) : .clear)
            )
            .shadow(color: isCold ? Theme.ice.opacity(0.2) : .clear, radius: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .fill(triggered ? Theme.orange.opacity(0.15) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(pendingStroke, lineWidth: 2)
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(topBorderColor)
                    .frame(height: 2)
            }
    }

    private var hotGlowStroke: Color {
        isHot && isActive ? Theme.orange.opacity(0.3 + 0.2 * breathe) : .clear
    }

    private var hotGlowShadow: Color {
        isHot && isActive ? Theme.orange.opacity(0.3 + 0.15 * breathe) : .clear
    }

    private var pendingStroke: Color {
        guard hasPending else { return .clear }
        let color = pendingMute == true ? Theme.ice : Theme.orange
        return color.opacity(pendingBlink ? 0.8 : 0.2)
    }

    private var topBorderColor: Color {
        if hasPending {
            let color = pendingMute == true ? Theme.ice : Theme.orange
            return color.opacity(pendingBlink ? 0.9 : 0.3)
        }
        if isHot && isActive { return Theme.orange }
        if isCold { return Theme.ice.opacity(0.6) }
        return .clear
    }
}
```

- [ ] **Step 2: Apply modifier in PadCell**

Replace lines 189-226 in PadCell's body with:

```swift
        .modifier(PadCellOverlay(
            isHot: isHot,
            isCold: isCold,
            isActive: isActive,
            triggered: triggered,
            hasPending: hasPending,
            pendingMute: pendingMute,
            breathe: breathe,
            pendingBlink: pendingBlink
        ))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                breathe = 1.0
            }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                pendingBlink = true
            }
        }
```

- [ ] **Step 3: Build and test**

Run: `cd ~/god/GOD && swift build && swift test`
Expected: Build succeeds. UI renders identically (visual verification at next manual test).

- [ ] **Step 4: Commit**

```bash
git add GOD/GOD/Views/PadStripView.swift
git commit -m "refactor: consolidate PadCell overlays into PadCellOverlay ViewModifier"
```

---

### Task 11: Enum-based KeyReferenceOverlay shortcuts (Item 11)

**Files:**
- Modify: `GOD/GOD/Views/KeyReferenceOverlay.swift`

- [ ] **Step 1: Replace string tuples with enum**

Rewrite `KeyReferenceOverlay.swift`:

```swift
import SwiftUI

enum KeyAction: CaseIterable {
    case play, capture, padLeft, padRight, padJump
    case cool, hot, browse, browseNav, closeBrowser
    case metronome, bpmMode, fewerBars, moreBars
    case masterVolume, volume, undoClear, cutMode
    case toggleMode, clearPad, stop, help

    var key: String {
        switch self {
        case .play:         return "SPC"
        case .capture:      return "G"
        case .padLeft:      return "A"
        case .padRight:     return "D"
        case .padJump:      return "⇧1-8"
        case .cool:         return "Q"
        case .hot:          return "E"
        case .browse:       return "T"
        case .browseNav:    return "W/S"
        case .closeBrowser: return "⏎/T/ESC"
        case .metronome:    return "M"
        case .bpmMode:      return "B"
        case .fewerBars:    return "["
        case .moreBars:     return "]"
        case .masterVolume: return "V"
        case .volume:       return "0-9"
        case .undoClear:    return "Z"
        case .cutMode:      return "X"
        case .toggleMode:   return "N"
        case .clearPad:     return "C"
        case .stop:         return "ESC"
        case .help:         return "?"
        }
    }

    var action: String {
        switch self {
        case .play:         return "play / stop"
        case .capture:      return "god capture"
        case .padLeft:      return "select pad left"
        case .padRight:     return "select pad right"
        case .padJump:      return "jump to pad 1-8"
        case .cool:         return "cool (mute) active pad"
        case .hot:          return "hot (unmute) active pad"
        case .browse:       return "browse samples for pad"
        case .browseNav:    return "browse + auto-load sample"
        case .closeBrowser: return "close browser"
        case .metronome:    return "metronome"
        case .bpmMode:      return "bpm mode (W/S presets or type)"
        case .fewerBars:    return "fewer bars"
        case .moreBars:     return "more bars"
        case .masterVolume: return "toggle master volume mode"
        case .volume:       return "volume (master or pad)"
        case .undoClear:    return "undo clear"
        case .cutMode:      return "cut mode"
        case .toggleMode:   return "toggle instant / next loop"
        case .clearPad:     return "clear active pad"
        case .stop:         return "stop"
        case .help:         return "this help"
        }
    }
}

struct KeyReferenceOverlay: View {
    @Binding var isVisible: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("KEYS")
                .font(Theme.monoLarge)
                .foregroundColor(Theme.text)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(KeyAction.allCases, id: \.self) { action in
                    HStack(spacing: 20) {
                        Text(action.key)
                            .foregroundColor(Theme.blue)
                            .frame(width: 60, alignment: .trailing)
                        Text(action.action)
                            .foregroundColor(Theme.text)
                    }
                }
            }

            Text("press ? to close")
                .font(Theme.monoSmall)
                .foregroundColor(Theme.subtle)
                .padding(.top, 12)
        }
        .font(Theme.mono)
        .padding(40)
        .background(Theme.bg.opacity(0.95))
    }
}
```

- [ ] **Step 2: Build and test**

Run: `cd ~/god/GOD && swift build && swift test`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add GOD/GOD/Views/KeyReferenceOverlay.swift
git commit -m "refactor: replace shortcut string tuples with KeyAction enum"
```

---

## Final Verification

- [ ] **Full build + test**

```bash
cd ~/god/GOD && swift build && swift test
```

Expected: Build succeeds. 88/89 tests pass (same pre-existing failure in `engineActivePadTracking`).

- [ ] **Update CODEBASE.md**

Per CLAUDE.md, update CODEBASE.md to reflect all changes: new AudioState struct, renamed constants, new Transport.currentBeat, KeyAction enum, PadCellOverlay modifier.

- [ ] **Final commit**

```bash
git add CODEBASE.md
git commit -m "docs: update CODEBASE.md to reflect code quality cleanup"
```

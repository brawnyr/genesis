# Inspector Rework, Pad Text & Cut Mode — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the inspector panel to a log-style terminal aesthetic, fix pad text readability with marquee scrolling, add per-pad cut mode, and auto-detect sample BPM.

**Architecture:** Four independent features that share the inspector panel as their display surface. Cut mode and BPM detection are engine-level changes with model additions. Pad text marquee and inspector rework are purely view-layer. Cut mode needs `X` key (not `C` — that's already "clear").

**Tech Stack:** Swift, SwiftUI, AVFoundation, Swift Testing

**Spec:** `docs/superpowers/specs/2026-03-11-inspector-rework-pad-text-design.md`

---

## Chunk 1: Cut Mode (Model + Engine + Keyboard)

### Task 1: Add `cut` property to Layer model

**Files:**
- Modify: `GOD/GOD/Models/Layer.swift:8-17`
- Test: `GOD/Tests/LayerTests.swift`

- [ ] **Step 1: Write failing test for cut default**

Add to `GOD/Tests/LayerTests.swift`:

```swift
@Test func layerCutDefaultsFalse() {
    let layer = Layer(index: 0, name: "KICK")
    #expect(layer.cut == false)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/god/GOD && swift test --filter layerCutDefaultsFalse`
Expected: FAIL — `Layer` has no `cut` property

- [ ] **Step 3: Add `cut` property to Layer**

In `GOD/GOD/Models/Layer.swift`, add after the `lpCutoff` line (line 16):

```swift
var cut: Bool = false
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/god/GOD && swift test --filter layerCutDefaultsFalse`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd ~/god && git add GOD/GOD/Models/Layer.swift GOD/Tests/LayerTests.swift
git commit -m "feat: add cut property to Layer model"
```

---

### Task 2: Add `cut` persistence to Pad model

**Files:**
- Modify: `GOD/GOD/Models/Pad.swift:3-19` (Pad struct, PadAssignment struct)
- Modify: `GOD/GOD/Models/Pad.swift:51-59` (PadBank.config computed property)
- Modify: `GOD/GOD/Models/Pad.swift:73-85` (PadBank.loadConfig)
- Test: `GOD/Tests/PadTests.swift`

- [ ] **Step 1: Write failing test for cut serialization**

Add to `GOD/Tests/PadTests.swift`:

```swift
@Test func padCutSerializationRoundTrip() {
    var pads = PadBank()
    pads.pads[0].samplePath = "/path/to/kick.wav"
    pads.pads[0].name = "KICK"
    pads.pads[0].cut = true
    let data = try! JSONEncoder().encode(pads.config)
    let decoded = try! JSONDecoder().decode(PadConfig.self, from: data)
    #expect(decoded.assignments["0"]?.cut == true)
}

@Test func padCutBackwardsCompat() {
    // Simulate old pads.json without cut key
    let json = """
    {"assignments":{"0":{"path":"/kick.wav","name":"KICK"}}}
    """
    let data = json.data(using: .utf8)!
    let decoded = try! JSONDecoder().decode(PadConfig.self, from: data)
    #expect(decoded.assignments["0"]?.cut == nil)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/god/GOD && swift test --filter padCut`
Expected: FAIL — `Pad` has no `cut`, `PadAssignment` has no `cut`

- [ ] **Step 3: Add cut to Pad and PadAssignment**

In `GOD/GOD/Models/Pad.swift`:

Add to `Pad` struct (after `isOneShot` line 9):
```swift
var cut: Bool = false
```

Add to `PadAssignment` struct (after `name` line 14):
```swift
var cut: Bool?
```

Update `PadBank.config` computed property — change the assignment line to:
```swift
cfg.assignments[String(pad.index)] = PadAssignment(path: path, name: pad.name, cut: pad.cut)
```

Update `PadBank.loadConfig()` — after `pads[index].name = assignment.name` add:
```swift
pads[index].cut = assignment.cut ?? false
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/god/GOD && swift test --filter padCut`
Expected: PASS

- [ ] **Step 5: Run all pad tests to check no regressions**

Run: `cd ~/god/GOD && swift test --filter pad`
Expected: All PASS (including existing `padConfigSerialization`)

- [ ] **Step 6: Commit**

```bash
cd ~/god && git add GOD/GOD/Models/Pad.swift GOD/Tests/PadTests.swift
git commit -m "feat: add cut persistence to PadAssignment with backwards compat"
```

---

### Task 3: Add `toggleCut` and voice chopping to GodEngine

**Files:**
- Modify: `GOD/GOD/Engine/GodEngine.swift:92-96` (after toggleMute)
- Modify: `GOD/GOD/Engine/GodEngine.swift:123-136` (handlePadHit)
- Modify: `GOD/GOD/Engine/GodEngine.swift:194-199` (processBlock loop-playback hits)
- Test: `GOD/Tests/GodEngineTests.swift`

- [ ] **Step 1: Write failing test for toggleCut**

Add to `GOD/Tests/GodEngineTests.swift`:

```swift
@Test @MainActor func engineToggleCut() {
    let engine = GodEngine()
    #expect(engine.layers[0].cut == false)
    engine.toggleCut(pad: 0)
    #expect(engine.layers[0].cut == true)
    engine.toggleCut(pad: 0)
    #expect(engine.layers[0].cut == false)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/god/GOD && swift test --filter engineToggleCut`
Expected: FAIL — no `toggleCut` method

- [ ] **Step 3: Implement toggleCut**

In `GOD/GOD/Engine/GodEngine.swift`, add after `toggleMute` (after line 96):

```swift
func toggleCut(pad index: Int) {
    guard index >= 0, index < layers.count else { return }
    layers[index].cut.toggle()
    audioLayers[index].cut = layers[index].cut
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/god/GOD && swift test --filter engineToggleCut`
Expected: PASS

- [ ] **Step 5: Write failing test for cut voice chopping**

Add to `GOD/Tests/GodEngineTests.swift`:

```swift
@Test @MainActor func engineCutModeChopsVoices() {
    let engine = GodEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "808", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.toggleCut(pad: 0)
    engine.togglePlay()

    // First hit — should create 1 voice
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)
    let voicesAfterFirst = engine.voices.filter { $0.padIndex == 0 }.count
    #expect(voicesAfterFirst == 1)

    // Second hit — cut should remove first, add new = still 1 voice
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)
    let voicesAfterSecond = engine.voices.filter { $0.padIndex == 0 }.count
    #expect(voicesAfterSecond == 1)
}

@Test @MainActor func engineNoCutModeStacksVoices() {
    let engine = GodEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "808", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    // cut is OFF (default)
    engine.togglePlay()

    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)

    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)

    let voices = engine.voices.filter { $0.padIndex == 0 }.count
    #expect(voices == 2)
}
```

- [ ] **Step 6: Run tests to verify they fail**

Run: `cd ~/god/GOD && swift test --filter engineCutMode && swift test --filter engineNoCutMode`
Expected: `engineCutModeChopsVoices` FAILS (voices == 2, not 1). `engineNoCutModeStacksVoices` should PASS (existing behavior).

- [ ] **Step 7: Add cut logic to handlePadHit**

In `GOD/GOD/Engine/GodEngine.swift`, in `handlePadHit`, add before the `voices.append` line (before line 132):

```swift
if audioLayers[padIndex].cut {
    voices.removeAll { $0.padIndex == padIndex }
}
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `cd ~/god/GOD && swift test --filter engineCutMode && swift test --filter engineNoCutMode`
Expected: Both PASS

- [ ] **Step 9: Add cut logic to processBlock loop-playback path**

In `GOD/GOD/Engine/GodEngine.swift`, in `processBlock` inside the loop-playback hit spawning (around line 194-199), change:

```swift
for hit in hits {
    if let sample = padBank.pads[layer.index].sample {
        let vel = Float(hit.velocity) / 127.0 * layer.volume
        voices.append(Voice(sample: sample, velocity: vel, padIndex: layer.index))
    }
}
```

to:

```swift
for hit in hits {
    if let sample = padBank.pads[layer.index].sample {
        if layer.cut {
            voices.removeAll { $0.padIndex == layer.index }
        }
        let vel = Float(hit.velocity) / 127.0 * layer.volume
        voices.append(Voice(sample: sample, velocity: vel, padIndex: layer.index))
    }
}
```

- [ ] **Step 10: Run all engine tests**

Run: `cd ~/god/GOD && swift test --filter engine`
Expected: All PASS

- [ ] **Step 11: Commit**

```bash
cd ~/god && git add GOD/GOD/Engine/GodEngine.swift GOD/Tests/GodEngineTests.swift
git commit -m "feat: add toggleCut and voice chopping for cut mode"
```

---

### Task 4: Add cut persistence sync in GodEngine

**Files:**
- Modify: `GOD/GOD/Engine/GodEngine.swift` (wherever config load/save happens)
- Modify: `GOD/GOD/ContentView.swift:171` (save path)

Note: The current `padBank.save()` is called in `ContentView.loadBrowserSample()` (line 171) and `SampleBrowserView.loadSelectedSample()` (PadStripView.swift line 382). We need to sync `layers[i].cut` to `padBank.pads[i].cut` before each save. The cleanest approach: add a `syncCutToPadBank()` helper on GodEngine and call it before saves.

- [ ] **Step 1: Add syncCutToPadBank helper to GodEngine**

In `GOD/GOD/Engine/GodEngine.swift`, add after `toggleCut`:

```swift
func syncCutToPadBank() {
    for i in 0..<8 {
        padBank.pads[i].cut = layers[i].cut
    }
}

func restoreCutFromPadBank() {
    for i in 0..<8 {
        layers[i].cut = padBank.pads[i].cut
        audioLayers[i].cut = padBank.pads[i].cut
    }
}
```

- [ ] **Step 2: Call restoreCutFromPadBank in GODApp.swift after config load**

In `GOD/GOD/GODApp.swift`, in `startManagers()` (line 117), add after `engine.padBank.loadFromSpliceFolders()` (line 121):

```swift
engine.restoreCutFromPadBank()
```

- [ ] **Step 3: Call syncCutToPadBank before saves**

In `ContentView.loadBrowserSample()`, before `try? engine.padBank.save()` (line 171), add:
```swift
engine.syncCutToPadBank()
```

In `PadStripView.swift` `SampleBrowserView.loadSelectedSample()`, before `try? engine.padBank.save()` (line 382), add:
```swift
engine.syncCutToPadBank()
```

In `PadStripView.swift` `SampleBrowserView.loadFromFilePicker()`, before `try? engine.padBank.save()` (line 399), add:
```swift
engine.syncCutToPadBank()
```

- [ ] **Step 4: Run all tests**

Run: `cd ~/god/GOD && swift test`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
cd ~/god && git add GOD/GOD/Engine/GodEngine.swift GOD/GOD/ContentView.swift GOD/GOD/Views/PadStripView.swift GOD/GOD/GODApp.swift
git commit -m "feat: sync cut mode state to/from pad config persistence"
```

---

### Task 5: Add `X` keyboard shortcut for cut toggle

**Files:**
- Modify: `GOD/GOD/ContentView.swift:130-151` (Key enum)
- Modify: `GOD/GOD/ContentView.swift:275-360` (switch statement)
- Modify: `GOD/GOD/ContentView.swift:99-116` (hotkeys strip)

- [ ] **Step 1: Add Key.x constant**

In `GOD/GOD/ContentView.swift`, in the `Key` enum (around line 130), add:

```swift
static let x: UInt16 = 7
```

- [ ] **Step 2: Add X key handler**

In the main `switch keyCode` block (around line 275-360), add before `default:`:

```swift
case Key.x:
    engine.toggleCut(pad: engine.activePadIndex)
    let cutState = engine.layers[engine.activePadIndex].cut ? "on" : "off"
    let name = padName(engine.activePadIndex)
    interpreter.appendLine("pad \(engine.activePadIndex + 1) \(name) cut \(cutState)", kind: .state)
```

- [ ] **Step 3: Add X to hotkeys strip**

In the hotkeys `HStack` (around line 99-116), add after the "clear" KeyLabel:

```swift
KeyLabel(key: "X", action: "cut")
```

- [ ] **Step 4: Build and verify**

Run: `cd ~/god/GOD && swift build`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
cd ~/god && git add GOD/GOD/ContentView.swift
git commit -m "feat: add X keyboard shortcut for cut mode toggle"
```

---

## Chunk 2: BPM Detection

### Task 6: Create BPMDetector

**Files:**
- Create: `GOD/GOD/Engine/BPMDetector.swift`
- Create: `GOD/Tests/BPMDetectorTests.swift`

- [ ] **Step 1: Write failing tests for BPM detection**

Create `GOD/Tests/BPMDetectorTests.swift`:

```swift
import Testing
@testable import GOD

@Test func bpmDetectorReturnsNilForShortSample() {
    // 0.2s at 44100 = 8820 frames, below 0.5s threshold
    let buffer = [Float](repeating: 0.0, count: 8820)
    let result = BPMDetector.detect(buffer: buffer, sampleRate: 44100)
    #expect(result == nil)
}

@Test func bpmDetectorReturnsBPMForRhythmicSignal() {
    // Generate a click track at 120 BPM (0.5s per beat) for 4 seconds
    let sampleRate = 44100.0
    let bpm = 120.0
    let duration = 4.0
    let samplesPerBeat = Int(60.0 / bpm * sampleRate)
    let totalSamples = Int(duration * sampleRate)
    var buffer = [Float](repeating: 0.0, count: totalSamples)

    // Place sharp transients at each beat
    for beat in 0..<Int(duration * bpm / 60.0) {
        let pos = beat * samplesPerBeat
        if pos < totalSamples {
            for i in 0..<min(200, totalSamples - pos) {
                buffer[pos + i] = Float.random(in: 0.5...1.0) * (1.0 - Float(i) / 200.0)
            }
        }
    }

    let result = BPMDetector.detect(buffer: buffer, sampleRate: sampleRate)
    #expect(result != nil)
    if let detected = result {
        // Should be within 10% of 120 BPM (accounting for detection imprecision)
        #expect(detected > 108 && detected < 132)
    }
}

@Test func bpmDetectorClampsToRange() {
    // Very fast clicks at 300 BPM should be halved into 70-180 range
    let sampleRate = 44100.0
    let bpm = 300.0
    let duration = 4.0
    let samplesPerBeat = Int(60.0 / bpm * sampleRate)
    let totalSamples = Int(duration * sampleRate)
    var buffer = [Float](repeating: 0.0, count: totalSamples)

    for beat in 0..<Int(duration * bpm / 60.0) {
        let pos = beat * samplesPerBeat
        if pos < totalSamples {
            for i in 0..<min(100, totalSamples - pos) {
                buffer[pos + i] = Float.random(in: 0.5...1.0)
            }
        }
    }

    let result = BPMDetector.detect(buffer: buffer, sampleRate: sampleRate)
    if let detected = result {
        #expect(detected >= 70 && detected <= 180)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/god/GOD && swift test --filter bpmDetector`
Expected: FAIL — `BPMDetector` not found

- [ ] **Step 3: Implement BPMDetector**

Create `GOD/GOD/Engine/BPMDetector.swift`:

```swift
import Foundation
import Accelerate

enum BPMDetector {
    /// Minimum sample duration for BPM detection (0.5 seconds)
    private static let minFrames = 22050

    /// Detect BPM from a mono audio buffer using energy-based onset detection.
    /// Returns nil if the sample is too short or detection fails.
    static func detect(buffer: [Float], sampleRate: Double) -> Double? {
        guard buffer.count >= minFrames else { return nil }

        // 1. Compute short-time energy in windows
        let windowSize = 1024
        let hopSize = 512
        let windowCount = (buffer.count - windowSize) / hopSize
        guard windowCount > 4 else { return nil }

        var energies = [Float](repeating: 0, count: windowCount)
        for i in 0..<windowCount {
            let start = i * hopSize
            let slice = Array(buffer[start..<start + windowSize])
            var sumSq: Float = 0
            vDSP_svesq(slice, 1, &sumSq, vDSP_Length(windowSize))
            energies[i] = sumSq
        }

        // 2. Compute onset detection function (first-order difference of energy)
        var onsetFunc = [Float](repeating: 0, count: windowCount - 1)
        for i in 0..<windowCount - 1 {
            onsetFunc[i] = max(0, energies[i + 1] - energies[i])
        }

        // 3. Find peaks in onset function (local maxima above mean)
        var mean: Float = 0
        vDSP_meanv(onsetFunc, 1, &mean, vDSP_Length(onsetFunc.count))
        let threshold = mean * 1.5

        var onsetPositions: [Int] = []
        for i in 1..<onsetFunc.count - 1 {
            if onsetFunc[i] > threshold &&
               onsetFunc[i] > onsetFunc[i - 1] &&
               onsetFunc[i] >= onsetFunc[i + 1] {
                onsetPositions.append(i)
            }
        }

        guard onsetPositions.count >= 2 else { return nil }

        // 4. Compute inter-onset intervals in seconds
        let hopDuration = Double(hopSize) / sampleRate
        var intervals: [Double] = []
        for i in 1..<onsetPositions.count {
            let interval = Double(onsetPositions[i] - onsetPositions[i - 1]) * hopDuration
            if interval > 0.15 && interval < 2.0 { // 30-400 BPM range
                intervals.append(interval)
            }
        }

        guard !intervals.isEmpty else { return nil }

        // 5. Find most common interval via histogram
        let binSize = 0.02 // 20ms bins
        var histogram: [Int: Int] = [:]
        for interval in intervals {
            let bin = Int(interval / binSize)
            histogram[bin, default: 0] += 1
        }

        guard let bestBin = histogram.max(by: { $0.value < $1.value }) else { return nil }
        let bestInterval = (Double(bestBin.key) + 0.5) * binSize
        var bpm = 60.0 / bestInterval

        // 6. Normalize to 70-180 BPM range
        while bpm > 180 { bpm /= 2 }
        while bpm < 70 { bpm *= 2 }

        return bpm
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/god/GOD && swift test --filter bpmDetector`
Expected: All PASS (the rhythmic signal test may need tolerance tuning — adjust if needed)

- [ ] **Step 5: Commit**

```bash
cd ~/god && git add GOD/GOD/Engine/BPMDetector.swift GOD/Tests/BPMDetectorTests.swift
git commit -m "feat: add BPM detector with energy-based onset detection"
```

---

### Task 7: Integrate BPM detection into GodEngine

**Files:**
- Modify: `GOD/GOD/Engine/GodEngine.swift` (add detectedBPMs dictionary, trigger detection on sample load)

- [ ] **Step 1: Add detectedBPMs property to GodEngine**

In `GOD/GOD/Engine/GodEngine.swift`, add after the `@Published var masterVolume` line:

```swift
@Published var detectedBPMs: [Int: Double] = [:]
```

- [ ] **Step 2: Add detectBPM helper method**

Add to `GodEngine`:

```swift
func detectBPM(forPad index: Int) {
    guard let sample = padBank.pads[index].sample else {
        detectedBPMs[index] = nil
        return
    }
    let buffer = sample.left
    let sampleRate = sample.sampleRate
    detectedBPMs[index] = nil  // clear while detecting
    Task.detached { [weak self] in
        let bpm = BPMDetector.detect(buffer: buffer, sampleRate: sampleRate)
        await MainActor.run {
            self?.detectedBPMs[index] = bpm
        }
    }
}
```

- [ ] **Step 3: Trigger BPM detection when samples are loaded**

In `ContentView.loadBrowserSample()`, after `engine.padBank.assign(sample: sample, toPad: padIndex)` add:
```swift
engine.detectBPM(forPad: padIndex)
```

In `PadStripView.swift` `SampleBrowserView.loadSelectedSample()`, after `engine.padBank.assign(sample: sample, toPad: padIndex)` add:
```swift
engine.detectBPM(forPad: padIndex)
```

In `PadStripView.swift` `SampleBrowserView.loadFromFilePicker()`, after `engine.padBank.assign(sample: sample, toPad: padIndex)` add:
```swift
engine.detectBPM(forPad: padIndex)
```

Also trigger detection on app startup in `GODApp.swift`, in `startManagers()` after `engine.restoreCutFromPadBank()`, add:
```swift
for i in 0..<8 {
    engine.detectBPM(forPad: i)
}
```

- [ ] **Step 4: Build and verify**

Run: `cd ~/god/GOD && swift build`
Expected: Build succeeds

- [ ] **Step 5: Run all tests**

Run: `cd ~/god/GOD && swift test`
Expected: All PASS

- [ ] **Step 6: Commit**

```bash
cd ~/god && git add GOD/GOD/Engine/GodEngine.swift GOD/GOD/ContentView.swift GOD/GOD/Views/PadStripView.swift
git commit -m "feat: integrate BPM detection into engine with async detection on sample load"
```

---

## Chunk 3: Pad Strip Marquee Text

### Task 8: Implement marquee scrolling for pad sample names

**Files:**
- Modify: `GOD/GOD/Views/PadStripView.swift:62-77` (PadCell body, sample name section)

- [ ] **Step 1: Create MarqueeText helper view**

Add above `PadCell` in `GOD/GOD/Views/PadStripView.swift`:

```swift
struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    let shadow: Color

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    private var overflows: Bool { textWidth > containerWidth && containerWidth > 0 }
    private let gap: CGFloat = 40
    private let speed: CGFloat = 30 // points per second

    var body: some View {
        GeometryReader { geo in
            let _ = updateContainerWidth(geo.size.width)
            ZStack(alignment: .leading) {
                if overflows {
                    HStack(spacing: gap) {
                        Text(text)
                            .font(font)
                            .foregroundColor(color)
                            .shadow(color: shadow, radius: 6)
                            .fixedSize()
                        Text(text)
                            .font(font)
                            .foregroundColor(color)
                            .shadow(color: shadow, radius: 6)
                            .fixedSize()
                    }
                    .offset(x: offset)
                    .onAppear { startAnimation() }
                    .onChange(of: text) { _, _ in resetAnimation() }
                } else {
                    Text(text)
                        .font(font)
                        .foregroundColor(color)
                        .shadow(color: shadow, radius: 6)
                        .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .clipped()
        }
        .background(
            Text(text)
                .font(font)
                .fixedSize()
                .background(GeometryReader { geo in
                    Color.clear.onAppear { textWidth = geo.size.width }
                        .onChange(of: text) { _, _ in textWidth = geo.size.width }
                })
                .hidden()
        )
        .frame(height: 18)
    }

    private func updateContainerWidth(_ width: CGFloat) {
        if containerWidth != width {
            DispatchQueue.main.async { containerWidth = width }
        }
    }

    private func startAnimation() {
        guard overflows else { return }
        let totalWidth = textWidth + gap
        let duration = Double(totalWidth) / Double(speed)
        offset = 0
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            offset = -totalWidth
        }
    }

    private func resetAnimation() {
        offset = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startAnimation()
        }
    }
}
```

- [ ] **Step 2: Replace Text in PadCell with MarqueeText**

In `PadCell.body`, replace the sample name `Text` block (lines 65-76):

```swift
Text(sampleLabel)
    .font(.system(size: 12, design: .monospaced).bold())
    .foregroundColor(
        isHot && isActive ? .white :
        isHot ? Theme.orange :
        isCold ? Theme.ice :
        Color(white: 0.15)
    )
    .shadow(color: isHot ? Theme.orange.opacity(isActive ? 0.6 : 0.3) : .clear, radius: 6)
    .shadow(color: isCold ? Theme.ice.opacity(0.4) : .clear, radius: 6)
    .lineLimit(1)
    .minimumScaleFactor(0.5)
```

with:

```swift
MarqueeText(
    text: sampleLabel,
    font: .system(size: 14, design: .monospaced).bold(),
    color: isHot && isActive ? .white :
           isHot ? Theme.orange :
           isCold ? Theme.ice :
           Color(white: 0.15),
    shadow: isHot ? Theme.orange.opacity(isActive ? 0.6 : 0.3) :
            isCold ? Theme.ice.opacity(0.4) :
            .clear
)
```

- [ ] **Step 3: Build and verify**

Run: `cd ~/god/GOD && swift build`
Expected: Build succeeds

- [ ] **Step 4: Manual test**

Run: `cd ~/god/GOD && swift build && .build/arm64-apple-macosx/debug/GOD`
Verify: Short sample names stay centered and static. Long sample names scroll smoothly left in a loop. Font is visibly larger (14pt vs old 12pt).

- [ ] **Step 5: Commit**

```bash
cd ~/god && git add GOD/GOD/Views/PadStripView.swift
git commit -m "feat: add marquee scroll for long pad sample names, bump font to 14pt"
```

---

## Chunk 4: Inspector Panel Rework

### Task 9: Rework CCPanelView master section

**Files:**
- Modify: `GOD/GOD/Views/PadStripView.swift:186-222` (CCPanelView body)

- [ ] **Step 1: Rework the master section and panel background**

In `CCPanelView.body`, replace the existing master section and panel styling. Change the full `body` computed property:

Replace the master section (lines 188-211):

```swift
Text("MASTER")
    .font(.system(size: 14, design: .monospaced).bold())
    .foregroundColor(masterVolumeMode ? Theme.orange : Theme.subtle)
HStack(alignment: .firstTextBaseline, spacing: 1) {
    Text("\(Int(engine.masterVolume * 100))")
        .font(.system(size: masterVolumeMode ? 44 : 32, design: .monospaced).bold())
        .foregroundColor(masterVolumeMode ? Theme.orange : Color(white: 0.6))
    Text("%")
        .font(.system(size: masterVolumeMode ? 20 : 16, design: .monospaced))
        .foregroundColor(masterVolumeMode ? Theme.orange.opacity(0.6) : Color(white: 0.4))
}
.shadow(color: masterVolumeMode ? Theme.orange.opacity(0.3) : .clear, radius: 8)

if masterVolumeMode {
    Text("[V] to exit")
        .font(.system(size: 11, design: .monospaced))
        .foregroundColor(Theme.orange.opacity(0.5))
        .padding(.top, 2)
}

Divider()
    .background(Theme.subtle.opacity(0.3))
    .padding(.vertical, 8)
```

with:

```swift
// Master section
HStack(spacing: 4) {
    Text("~")
        .font(.system(size: 11, design: .monospaced))
        .foregroundColor(Theme.orange.opacity(0.4))
    Text("MASTER")
        .font(.system(size: 11, design: .monospaced))
        .foregroundColor(Color.white.opacity(0.35))
        .tracking(1)
}
HStack(alignment: .firstTextBaseline, spacing: 2) {
    Text("\(Int(engine.masterVolume * 100))")
        .font(.system(size: 36, design: .monospaced).bold())
        .foregroundColor(masterVolumeMode ? Theme.orange : Color(white: 0.7))
    Text("%")
        .font(.system(size: 14, design: .monospaced))
        .foregroundColor(masterVolumeMode ? Theme.orange.opacity(0.6) : Color(white: 0.3))
}
.shadow(color: Theme.orange.opacity(masterVolumeMode ? 0.3 : 0.15), radius: 20)
.padding(.top, 6)

if masterVolumeMode {
    Text("[V] to exit")
        .font(.system(size: 10, design: .monospaced))
        .foregroundColor(Theme.orange.opacity(0.5))
        .padding(.top, 2)
}

Rectangle()
    .fill(Color.white.opacity(0.04))
    .frame(height: 1)
    .padding(.vertical, 8)
```

Also change the panel background (line 221):

```swift
.background(Color(red: 0.1, green: 0.095, blue: 0.088))
```

to:

```swift
.background(Color(red: 0.071, green: 0.067, blue: 0.059))
```

- [ ] **Step 2: Build and verify**

Run: `cd ~/god/GOD && swift build`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
cd ~/god && git add GOD/GOD/Views/PadStripView.swift
git commit -m "feat: rework inspector master section with log-style terminal aesthetic"
```

---

### Task 10: Rework padReadoutView with log-style sections

**Files:**
- Modify: `GOD/GOD/Views/PadStripView.swift:224-262` (padReadoutView)

- [ ] **Step 1: Create InspectorSectionHeader helper**

Add above `CCPanelView` in `PadStripView.swift`:

```swift
struct InspectorSectionHeader: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text("▶")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.3))
                .tracking(0.5)
        }
    }
}

struct InspectorRow: View {
    let label: String
    let value: String
    let highlight: Bool
    let labelWidth: CGFloat

    init(label: String, value: String, highlight: Bool = false, labelWidth: CGFloat = 40) {
        self.label = label
        self.value = value
        self.highlight = highlight
        self.labelWidth = labelWidth
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .foregroundColor(Color.white.opacity(0.3))
                .frame(width: labelWidth, alignment: .leading)
            Text(value)
                .foregroundColor(highlight ? Theme.orange : Color.white.opacity(0.6))
                .shadow(color: highlight ? Theme.orange.opacity(0.2) : .clear, radius: 4)
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.vertical, 1)
    }
}

struct CutBadge: View {
    let isOn: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("cut")
                .foregroundColor(Color.white.opacity(0.3))
                .frame(width: 40, alignment: .leading)
            Text(isOn ? "ON" : "OFF")
                .font(.system(size: 11, design: .monospaced).bold())
                .foregroundColor(isOn ? Theme.orange : Color.white.opacity(0.3))
                .padding(.horizontal, 8)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isOn ? Theme.orange.opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(isOn ? Theme.orange.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: isOn ? Theme.orange.opacity(0.3) : .clear, radius: 6)
            if isOn {
                Text("notes chop")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.2))
            }
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.vertical, 1)
    }
}
```

- [ ] **Step 2: Replace padReadoutView**

Replace the entire `padReadoutView` computed property (lines 224-262):

```swift
private var padReadoutView: some View {
    VStack(alignment: .leading, spacing: 0) {
        // Pad number + folder
        HStack(spacing: 6) {
            Text("\(activeIndex + 1)")
                .font(.system(size: 28, design: .monospaced).bold())
                .foregroundColor(layer.isMuted ? Theme.ice : Theme.orange)
            Text(folderName.uppercased())
                .font(.system(size: 16, design: .monospaced).bold())
                .foregroundColor(layer.isMuted ? Theme.ice.opacity(0.7) : Theme.orange.opacity(0.7))
        }
        .shadow(color: (layer.isMuted ? Theme.ice : Theme.orange).opacity(0.2), radius: 6)
        .padding(.bottom, 4)

        if let sample = pad.sample {
            Text(sample.name.lowercased())
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Color(white: 0.55))
                .lineLimit(1)
        } else {
            Text("[no sample]")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Theme.subtle)
        }

        Divider()
            .background(Theme.subtle.opacity(0.3))
            .padding(.vertical, 8)

        CCRow(label: "vol", value: "\(Int(layer.volume * 100))%", highlight: !masterVolumeMode)
        CCRow(label: "pan", value: EngineEventInterpreter.formatPan(layer.pan), highlight: false)
        CCRow(label: "HP", value: EngineEventInterpreter.formatFrequency(layer.hpCutoff),
              highlight: layer.hpCutoff > 21)
        CCRow(label: "LP", value: EngineEventInterpreter.formatFrequency(layer.lpCutoff),
              highlight: layer.lpCutoff < 19999)

        Spacer()
    }
}
```

with:

```swift
private var padReadoutView: some View {
    VStack(alignment: .leading, spacing: 0) {
        // Channel name — hero
        Text(folderName.uppercased())
            .font(.system(size: 22, design: .monospaced).bold())
            .foregroundColor(layer.isMuted ? Theme.ice : Theme.orange)
            .tracking(2)
            .shadow(color: (layer.isMuted ? Theme.ice : Theme.orange).opacity(0.4), radius: 25)

        Rectangle()
            .fill(Color.white.opacity(0.04))
            .frame(height: 1)
            .padding(.vertical, 10)

        // SAMPLE section
        InspectorSectionHeader(title: "SAMPLE", color: Theme.blue.opacity(0.5))
            .padding(.bottom, 6)

        VStack(alignment: .leading, spacing: 0) {
            if let sample = pad.sample {
                InspectorRow(label: "file", value: sample.name.lowercased(), labelWidth: 40)
                InspectorRow(label: "dur", value: String(format: "%.2fs", sample.durationMs / 1000.0), labelWidth: 40)
                if let bpm = engine.detectedBPMs[activeIndex] {
                    InspectorRow(label: "bpm", value: "\(Int(bpm))", highlight: true, labelWidth: 40)
                } else {
                    InspectorRow(label: "bpm", value: "--", labelWidth: 40)
                }
            } else {
                InspectorRow(label: "file", value: "--", labelWidth: 40)
            }
        }
        .padding(.leading, 16)

        Rectangle()
            .fill(Color.white.opacity(0.04))
            .frame(height: 1)
            .padding(.vertical, 10)

        // PARAMS section
        InspectorSectionHeader(title: "PARAMS", color: Theme.orange.opacity(0.5))
            .padding(.bottom, 6)

        VStack(alignment: .leading, spacing: 0) {
            InspectorRow(label: "vol", value: "\(Int(layer.volume * 100))%", highlight: !masterVolumeMode)
            InspectorRow(label: "pan", value: EngineEventInterpreter.formatPan(layer.pan))
            InspectorRow(label: "HP", value: EngineEventInterpreter.formatFrequency(layer.hpCutoff),
                         highlight: layer.hpCutoff > 21)
            InspectorRow(label: "LP", value: EngineEventInterpreter.formatFrequency(layer.lpCutoff),
                         highlight: layer.lpCutoff < 19999)
        }
        .padding(.leading, 16)

        Rectangle()
            .fill(Color.white.opacity(0.04))
            .frame(height: 1)
            .padding(.vertical, 10)

        // MODE section
        InspectorSectionHeader(title: "MODE", color: Theme.orange.opacity(0.5))
            .padding(.bottom, 6)

        CutBadge(isOn: layer.cut)
            .padding(.leading, 16)

        Spacer()
    }
}
```

- [ ] **Step 3: Remove old CCRow struct**

Delete the old `CCRow` struct (lines 409-426 approximately) since it's replaced by `InspectorRow`. Search for any other uses of `CCRow` first — if none exist outside `padReadoutView`, safe to remove.

- [ ] **Step 4: Build and verify**

Run: `cd ~/god/GOD && swift build`
Expected: Build succeeds

- [ ] **Step 5: Manual test**

Run: `cd ~/god/GOD && swift build && .build/arm64-apple-macosx/debug/GOD`
Verify:
- Inspector shows channel name (e.g., "KICKS") as large glowing header
- No pad number visible
- SAMPLE section shows file, dur, bpm with section header
- PARAMS section shows vol, pan, HP, LP
- MODE section shows cut badge (ON/OFF)
- Press X to toggle cut — badge updates
- Background is slightly darker
- Muted channels show ice-blue instead of orange

- [ ] **Step 6: Commit**

```bash
cd ~/god && git add GOD/GOD/Views/PadStripView.swift
git commit -m "feat: rework inspector panel with log-style terminal sections"
```

---

### Task 11: Final integration test

- [ ] **Step 1: Run all tests**

Run: `cd ~/god/GOD && swift test`
Expected: All PASS

- [ ] **Step 2: Full manual smoke test**

Run: `cd ~/god/GOD && swift build && .build/arm64-apple-macosx/debug/GOD`

Verify everything works together:
1. Pad names: 14pt, long names scroll, short names static
2. Inspector: log-style with SAMPLE/PARAMS/MODE sections
3. Channel name is hero, no pad number
4. Press X: cut toggles, badge updates, terminal shows message
5. BPM detection: shows detected BPM in SAMPLE section (may take a moment)
6. Press A/D to switch pads — inspector updates
7. Press Q/E to mute/unmute — inspector colors change to ice/orange
8. Browse samples (T) — still works, BPM re-detects on new sample
9. Clear (C) — still works
10. All other shortcuts work as before

- [ ] **Step 3: Commit any final tweaks if needed**

- [ ] **Step 4: Final commit**

```bash
cd ~/god && git add GOD/GOD/Views/PadStripView.swift GOD/GOD/Engine/GodEngine.swift GOD/GOD/Engine/BPMDetector.swift GOD/GOD/Models/Layer.swift GOD/GOD/Models/Pad.swift GOD/GOD/ContentView.swift GOD/GOD/GODApp.swift
git commit -m "feat: complete inspector rework, pad marquee, cut mode, BPM detection"
```

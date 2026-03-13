# Swing & Terminal Trigger View Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-pad swing (live, non-destructive groove shift) and a crystalline terminal trigger view (multi-track piano roll) to the GOD looper.

**Architecture:** Swing is pure playback math in ProcessBlock — hits stay stored at raw frame positions, swing offset applied at read time via expanded-range scan. The trigger view is a new SwiftUI view (`TriggerMatrixView`) that reads engine layers and renders monospace hit glyphs with a sweeping cursor. A shared `SwingMath` utility provides the sixteenth-note classification logic for both audio and UI threads.

**Tech Stack:** Swift 5.9, SwiftUI, CoreAudio (existing), Swift Testing

---

## Chunk 1: Per-Pad Swing (Model + Engine)

### Task 1: Add swing property to Layer

**Files:**
- Modify: `GOD/GOD/Models/Layer.swift:14-28`
- Test: `GOD/Tests/LayerTests.swift`

- [ ] **Step 1: Write failing test for swing default**

```swift
// Append to GOD/Tests/LayerTests.swift
@Test func layerSwingDefaultValue() {
    let layer = Layer(index: 0, name: "KICK")
    #expect(layer.swing == 0.5)
}

@Test func layerSwingClamped() {
    var layer = Layer(index: 0, name: "KICK")
    layer.swing = 0.3
    #expect(layer.swing == 0.5)
    layer.swing = 0.9
    #expect(layer.swing == 0.75)
    layer.swing = 0.65
    #expect(layer.swing == 0.65)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/god/GOD && swift test --filter layerSwing 2>&1 | tail -5`
Expected: FAIL — `swing` property does not exist

- [ ] **Step 3: Add swing property to Layer**

In `GOD/GOD/Models/Layer.swift`, add after line 28 (`var tcps: Bool = true`):

```swift
var swing: Float = 0.5 {
    didSet { swing = max(0.5, min(0.75, swing)) }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/god/GOD && swift test --filter layerSwing 2>&1 | tail -5`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd ~/god && git add GOD/GOD/Models/Layer.swift GOD/Tests/LayerTests.swift
git commit -m "feat: add per-pad swing property to Layer (0.5–0.75, clamped)"
```

### Task 2: Create SwingMath utility

**Files:**
- Create: `GOD/GOD/Engine/SwingMath.swift`
- Test: `GOD/Tests/SwingMathTests.swift`

- [ ] **Step 1: Write failing tests for swing math**

Create `GOD/Tests/SwingMathTests.swift`:

```swift
import Testing
@testable import GOD

@Test func swungPositionNoSwing() {
    // Swing 0.5 = straight, no offset regardless of position
    let result = SwingMath.swungPosition(hitFrame: 1000, swing: 0.5, sixteenthLength: 5513, loopLength: 88200)
    #expect(result == 1000)
}

@Test func swungPositionEvenSlotUnchanged() {
    // Hit exactly on an even 16th (slot 0) — never shifted
    let sixteenth = 5513  // 1 bar @ 120bpm, 44100sr → 88200 / 16
    let result = SwingMath.swungPosition(hitFrame: 0, swing: 0.66, sixteenthLength: sixteenth, loopLength: 88200)
    #expect(result == 0)
}

@Test func swungPositionOddSlotShifted() {
    // Hit on slot 1 (odd) — should shift forward
    let sixteenth = 5512  // 88200 / 16 = 5512.5, truncated
    let hitFrame = sixteenth  // exactly at slot 1
    let result = SwingMath.swungPosition(hitFrame: hitFrame, swing: 0.66, sixteenthLength: sixteenth, loopLength: 88200)
    let expectedOffset = Int(Float(0.66 - 0.5) * Float(sixteenth))
    #expect(result == hitFrame + expectedOffset)
}

@Test func swungPositionWrapsAtLoopEnd() {
    // Hit near end of loop, swing pushes it past loopLength
    let loopLen = 88200
    let sixteenth = loopLen / 16  // 5512
    let hitFrame = loopLen - 100  // near the end, on an odd slot
    let result = SwingMath.swungPosition(hitFrame: hitFrame, swing: 0.75, sixteenthLength: sixteenth, loopLength: loopLen)
    // Should wrap around
    #expect(result >= 0)
    #expect(result < loopLen)
}

@Test func maxSwingOffsetCalculation() {
    let sixteenth = 5512
    let maxOffset = SwingMath.maxSwingOffset(sixteenthLength: sixteenth)
    // (0.75 - 0.5) * 5512 = 1378
    #expect(maxOffset == Int(0.25 * Float(sixteenth)))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/god/GOD && swift test --filter swung 2>&1 | tail -5`
Expected: FAIL — `SwingMath` does not exist

- [ ] **Step 3: Implement SwingMath**

Create `GOD/GOD/Engine/SwingMath.swift`:

```swift
import Foundation

enum SwingMath {
    /// Compute the swung playback position for a hit.
    /// - Parameters:
    ///   - hitFrame: The stored frame position of the hit
    ///   - swing: Swing amount (0.5 = straight, 0.75 = heavy shuffle)
    ///   - sixteenthLength: Length of one sixteenth note in frames
    ///   - loopLength: Total loop length in frames
    /// - Returns: The frame position where this hit should actually play
    static func swungPosition(hitFrame: Int, swing: Float, sixteenthLength: Int, loopLength: Int) -> Int {
        guard swing > 0.5, sixteenthLength > 0, loopLength > 0 else { return hitFrame }

        // Classify to nearest sixteenth-note slot
        let slotIndex = Int((Float(hitFrame) / Float(sixteenthLength)).rounded())

        // Only odd slots (off-beats) get swung
        guard slotIndex % 2 == 1 else { return hitFrame }

        let offset = Int((swing - 0.5) * Float(sixteenthLength))
        let swung = hitFrame + offset

        // Wrap at loop boundary
        return swung % loopLength
    }

    /// Maximum possible swing offset in frames (used to expand scan range).
    static func maxSwingOffset(sixteenthLength: Int) -> Int {
        return Int(0.25 * Float(sixteenthLength))  // 0.75 - 0.5 = 0.25
    }

    /// Calculate sixteenth note length in frames.
    static func sixteenthLength(loopLengthFrames: Int, beatsPerLoop: Int) -> Int {
        guard beatsPerLoop > 0 else { return 0 }
        return loopLengthFrames / (beatsPerLoop * 4)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/god/GOD && swift test --filter "swung|maxSwing" 2>&1 | tail -10`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
cd ~/god && git add GOD/GOD/Engine/SwingMath.swift GOD/Tests/SwingMathTests.swift
git commit -m "feat: add SwingMath utility for sixteenth-note swing classification"
```

### Task 3: Add swing to AudioState and CC handler

**Files:**
- Modify: `GOD/GOD/Engine/GodEngine.swift:16-36` (AudioState)
- Modify: `GOD/GOD/Engine/GodEngine+ProcessBlock.swift:54-79` (handleCC)
- Test: `GOD/Tests/GodEngineTests.swift`

- [ ] **Step 1: Write failing test for CC 18 swing control**

Append to `GOD/Tests/GodEngineTests.swift`:

```swift
@Test @MainActor func engineCC18SetsSwing() {
    let engine = GodEngine()
    engine.togglePlay()

    // CC 18 value 0 → swing 0.5 (straight)
    engine.midiRingBuffer.write(.cc(number: 18, value: 0))
    let _ = engine.processBlock(frameCount: 512)
    #expect(engine.audio.layers[0].swing == 0.5)

    // CC 18 value 127 → swing 0.75 (max)
    engine.midiRingBuffer.write(.cc(number: 18, value: 127))
    let _ = engine.processBlock(frameCount: 512)
    #expect(abs(engine.audio.layers[0].swing - 0.75) < 0.01)

    // CC 18 value 64 → swing ~0.625
    engine.midiRingBuffer.write(.cc(number: 18, value: 64))
    let _ = engine.processBlock(frameCount: 512)
    #expect(engine.audio.layers[0].swing > 0.6)
    #expect(engine.audio.layers[0].swing < 0.65)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/god/GOD && swift test --filter engineCC18 2>&1 | tail -5`
Expected: FAIL

- [ ] **Step 3: Add CC 18 handler**

In `GOD/GOD/Engine/GodEngine+ProcessBlock.swift`, in the `handleCC` function, add a new case before `default:` (line 74):

```swift
case 18: // Swing (knob 5)
    audio.layers[audio.activePadIndex].swing = 0.5 + (Float(value) / 127.0) * 0.25
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/god/GOD && swift test --filter engineCC18 2>&1 | tail -5`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd ~/god && git add GOD/GOD/Engine/GodEngine+ProcessBlock.swift GOD/Tests/GodEngineTests.swift
git commit -m "feat: add CC 18 handler for per-pad swing control"
```

### Task 4: Apply swing in ProcessBlock hit scan

**Files:**
- Modify: `GOD/GOD/Engine/GodEngine+ProcessBlock.swift:116-147` (loop replay section)
- Test: `GOD/Tests/GodEngineTests.swift`

- [ ] **Step 1: Write failing test for swung playback**

Append to `GOD/Tests/GodEngineTests.swift`:

```swift
@Test @MainActor func engineSwingShiftsPlayback() {
    let engine = GodEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "hat", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.audio.activePadIndex = 0
    engine.togglePlay()

    let loopLen = engine.audio.loopLengthFrames
    let beatsPerLoop = engine.audio.barCount * Transport.beatsPerBar
    let sixteenth = SwingMath.sixteenthLength(loopLengthFrames: loopLen, beatsPerLoop: beatsPerLoop)

    // Place hit exactly at slot 1 (odd = will be swung)
    engine.audio.layers[0].addHit(at: sixteenth, velocity: 100)
    engine.audio.layers[0].padState = .alive
    engine.audio.layers[0].hasNewHits = false

    // With no swing, hit triggers at frame = sixteenth
    engine.audio.layers[0].swing = 0.5
    engine.audio.position = sixteenth
    engine.voices.removeAll()
    let _ = engine.processBlock(frameCount: 512)
    #expect(engine.voices.count >= 1, "Hit should trigger at stored position with no swing")

    // With swing 0.75, hit should NOT trigger at stored position
    engine.audio.layers[0].swing = 0.75
    engine.audio.position = sixteenth
    engine.voices.removeAll()
    let _ = engine.processBlock(frameCount: 512)
    // The hit is swung forward, so it should not trigger at the original position
    // (it triggers later at sixteenth + offset)

    // Now position at the swung location — should trigger
    let offset = SwingMath.maxSwingOffset(sixteenthLength: sixteenth)
    engine.audio.position = sixteenth + offset
    engine.voices.removeAll()
    let _ = engine.processBlock(frameCount: 512)
    #expect(engine.voices.count >= 1, "Hit should trigger at swung position")
}

@Test @MainActor func engineSwingExpandedBackwardScan() {
    // Test that a hit stored BEFORE the block start triggers when swung INTO the block
    let engine = GodEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "hat", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.audio.activePadIndex = 0
    engine.togglePlay()

    let loopLen = engine.audio.loopLengthFrames
    let beatsPerLoop = engine.audio.barCount * Transport.beatsPerBar
    let sixteenth = SwingMath.sixteenthLength(loopLengthFrames: loopLen, beatsPerLoop: beatsPerLoop)
    let offset = SwingMath.maxSwingOffset(sixteenthLength: sixteenth)

    // Place hit at slot 1 (odd)
    engine.audio.layers[0].addHit(at: sixteenth, velocity: 100)
    engine.audio.layers[0].padState = .alive
    engine.audio.layers[0].swing = 0.75

    // Position the block AFTER the stored hit but AT the swung position
    // The stored hit is at `sixteenth`, swung to `sixteenth + offset`
    // Set block start just before the swung position
    engine.audio.position = sixteenth + offset - 10
    engine.voices.removeAll()
    let _ = engine.processBlock(frameCount: 512)

    // The backward scan should find the hit and trigger it at the swung position
    #expect(engine.voices.count >= 1, "Backward scan should catch hit swung into this block")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/god/GOD && swift test --filter engineSwingShifts 2>&1 | tail -5`
Expected: FAIL — ProcessBlock doesn't apply swing yet

- [ ] **Step 3: Modify ProcessBlock loop replay to apply swing**

Replace the loop replay section in `GOD/GOD/Engine/GodEngine+ProcessBlock.swift` (lines 122-147). The section starting with `for layer in audio.layers where !layer.isMuted && layer.padState == .alive {` becomes:

```swift
            for layerIdx in 0..<audio.layers.count {
                let layer = audio.layers[layerIdx]
                guard !layer.isMuted, layer.padState == .alive else { continue }

                let beatsPerLoop = audio.barCount * Transport.beatsPerBar
                let sixteenthLen = SwingMath.sixteenthLength(loopLengthFrames: loopLen, beatsPerLoop: beatsPerLoop)
                let maxOffset = SwingMath.maxSwingOffset(sixteenthLength: sixteenthLen)
                let endPos = startPos + frameCount

                // Expand scan range backward to catch hits swung into this block
                let scanStart = startPos - maxOffset
                let scanEnd = endPos

                let hits: [Hit]
                if scanStart < 0 {
                    // Scan wraps backward past loop start
                    let beforeWrap = layer.hits(inRange: (loopLen + scanStart)..<loopLen)
                    let mainRange = layer.hits(inRange: 0..<min(scanEnd, loopLen))
                    hits = beforeWrap + mainRange
                } else if scanEnd <= loopLen {
                    hits = layer.hits(inRange: scanStart..<scanEnd)
                } else {
                    let beforeWrap = layer.hits(inRange: scanStart..<loopLen)
                    let afterWrap = layer.hits(inRange: 0..<(scanEnd - loopLen))
                    hits = beforeWrap + afterWrap
                }

                for hit in hits {
                    let swungFrame = SwingMath.swungPosition(
                        hitFrame: hit.position,
                        swing: layer.swing,
                        sixteenthLength: sixteenthLen,
                        loopLength: loopLen
                    )

                    // Check if swung position falls within this block
                    let inBlock: Bool
                    if endPos <= loopLen {
                        inBlock = swungFrame >= startPos && swungFrame < endPos
                    } else {
                        // Block wraps around loop boundary
                        inBlock = swungFrame >= startPos || swungFrame < (endPos - loopLen)
                    }
                    guard inBlock else { continue }

                    if let sample = padBank.pads[layer.index].sample {
                        voices.removeAll { $0.padIndex == layer.index }
                        let vel = velocityMode == .full ? Float(1.0) : Float(hit.velocity) / 127.0
                        var offset = swungFrame - startPos
                        if offset < 0 { offset += loopLen }
                        var voice = Voice(sample: sample, velocity: vel, padIndex: layer.index)
                        voice.blockOffset = max(0, min(offset, frameCount - 1))
                        voices.append(voice)
                    }
                }
            }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/god/GOD && swift test 2>&1 | tail -15`
Expected: All tests PASS (both new and existing)

- [ ] **Step 5: Commit**

```bash
cd ~/god && git add GOD/GOD/Engine/GodEngine+ProcessBlock.swift GOD/Tests/GodEngineTests.swift
git commit -m "feat: apply swing offset in ProcessBlock loop replay with expanded-range scan"
```

### Task 5: Add swing keyboard controls and UI sync

**Files:**
- Modify: `GOD/GOD/ContentView+KeyHandlers.swift:6-26` (Key enum) and `164-291` (handleNormalKey)
- Modify: `GOD/GOD/Engine/GodEngine.swift` (add setSwing method)
- Modify: `GOD/GOD/Engine/GodEngine+ProcessBlock.swift:280-330` (UI sync throttle — sync swing to UI)

- [ ] **Step 1: Add V key code to Key enum**

In `GOD/GOD/ContentView+KeyHandlers.swift`, add to the `Key` enum (after line 21, `static let p: UInt16 = 35`):

```swift
static let v: UInt16 = 9
```

- [ ] **Step 2: Add setSwing method to GodEngine**

In `GOD/GOD/Engine/GodEngine.swift`, add after the `setLayerVolume` method (after line 205):

```swift
func setSwing(_ index: Int, swing: Float) {
    guard index >= 0, index < layers.count else { return }
    layers[index].swing = swing  // didSet clamps to 0.5–0.75
    os_unfair_lock_lock(&audioLock)
    audio.layers[index].swing = layers[index].swing
    os_unfair_lock_unlock(&audioLock)
}
```

- [ ] **Step 3: Add V / Shift+V key handler**

In `GOD/GOD/ContentView+KeyHandlers.swift`, in `handleNormalKey`, add a new case before `default:` (before line 289):

```swift
case Key.v:
    let idx = engine.activePadIndex
    let current = engine.layers[idx].swing
    if hasShift {
        engine.setSwing(idx, swing: current - 0.01)
    } else {
        engine.setSwing(idx, swing: current + 0.01)
    }
    let pct = Int((engine.layers[idx].swing - 0.5) / 0.25 * 100)
    interpreter.appendLine("pad \(idx + 1) swing → \(pct)%", kind: .state)
```

- [ ] **Step 4: Add swing to UI sync in ProcessBlock**

In `GOD/GOD/Engine/GodEngine+ProcessBlock.swift`, in the UI throttle block, add `swing` to the layer data being synced. After line 291 (`let layerLPCutoffs = audio.layers.map { $0.lpCutoff }`), add:

```swift
let layerSwings = audio.layers.map { $0.swing }
```

And in the `DispatchQueue.main.async` block, after line 327 (`self.layers[i].lpCutoff = layerLPCutoffs[i]`), add:

```swift
self.layers[i].swing = layerSwings[i]
```

- [ ] **Step 5: Add V to hotkey strip**

In `GOD/GOD/ContentView.swift`, add a new `KeyLabel` in the hotkeys HStack (after the "vol" label, around line 90):

```swift
KeyLabel(key: "V", action: "swing")
```

- [ ] **Step 6: Build and verify**

Run: `cd ~/god/GOD && swift build 2>&1 | tail -5`
Expected: Build succeeded

- [ ] **Step 7: Run all tests**

Run: `cd ~/god/GOD && swift test 2>&1 | tail -15`
Expected: All PASS

- [ ] **Step 8: Commit**

```bash
cd ~/god && git add GOD/GOD/ContentView+KeyHandlers.swift GOD/GOD/Engine/GodEngine.swift GOD/GOD/Engine/GodEngine+ProcessBlock.swift GOD/GOD/ContentView.swift
git commit -m "feat: add V/Shift+V keyboard controls and UI sync for per-pad swing"
```

---

## Chunk 2: Terminal Trigger View

### Task 6: Create TriggerMatrixView and TriggerRowView

**Files:**
- Create: `GOD/GOD/Views/TriggerMatrixView.swift`
- Create: `GOD/GOD/Views/TriggerRowView.swift`

- [ ] **Step 1: Create TriggerMatrixView**

Create `GOD/GOD/Views/TriggerMatrixView.swift`:

```swift
// GOD/GOD/Views/TriggerMatrixView.swift
import SwiftUI

struct TriggerMatrixView: View {
    @ObservedObject var engine: GodEngine

    /// Pads that should show rows: have hits or are armed (red)
    private var visibleLayers: [(index: Int, layer: Layer)] {
        engine.layers.enumerated().compactMap { i, layer in
            if !layer.hits.isEmpty || layer.padState == .red {
                return (index: i, layer: layer)
            }
            return nil
        }
    }

    var body: some View {
        GeometryReader { geo in
            let loopLen = engine.transport.loopLengthFrames
            let beatsPerLoop = engine.transport.barCount * Transport.beatsPerBar
            let sixteenthLen = SwingMath.sixteenthLength(loopLengthFrames: loopLen, beatsPerLoop: beatsPerLoop)
            let cursorFrac = loopLen > 0 ? CGFloat(engine.transport.position) / CGFloat(loopLen) : 0
            let nameWidth: CGFloat = 72
            let trackWidth = geo.size.width - nameWidth - 16  // 8px padding each side

            if visibleLayers.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(visibleLayers, id: \.index) { item in
                        TriggerRowView(
                            layer: item.layer,
                            padName: engine.padBank.pads[item.index].name,
                            loopLength: loopLen,
                            sixteenthLength: sixteenthLen,
                            beatsPerLoop: beatsPerLoop,
                            cursorFraction: cursorFrac,
                            trackWidth: trackWidth,
                            nameWidth: nameWidth,
                            isActive: item.index == engine.activePadIndex
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(.horizontal, 8)
                .animation(.easeInOut(duration: 0.3), value: visibleLayers.map(\.index))
            }
        }
    }
}
```

- [ ] **Step 2: Create TriggerRowView**

Create `GOD/GOD/Views/TriggerRowView.swift`:

```swift
// GOD/GOD/Views/TriggerRowView.swift
import SwiftUI

struct TriggerRowView: View {
    let layer: Layer
    let padName: String
    let loopLength: Int
    let sixteenthLength: Int
    let beatsPerLoop: Int
    let cursorFraction: CGFloat
    let trackWidth: CGFloat
    let nameWidth: CGFloat
    let isActive: Bool

    private var hitColor: Color {
        switch layer.padState {
        case .red: return Theme.red
        case .alive: return Theme.orange
        case .clear: return Theme.ice
        }
    }

    private func hitGlyph(velocity: Int) -> String {
        if velocity >= 100 { return "\u{25C6}" }      // ◆
        if velocity >= 40 { return "\u{25C7}" }        // ◇
        return "\u{00B7}"                               // ·
    }

    private func hitOpacity(velocity: Int) -> Double {
        if velocity >= 100 { return 1.0 }
        if velocity >= 40 { return 0.75 }
        return 0.45
    }

    var body: some View {
        HStack(spacing: 0) {
            // Pad name
            Text(padName.prefix(8).uppercased())
                .font(.system(size: 10, design: .monospaced).bold())
                .foregroundColor(isActive ? Theme.orange : Theme.ice.opacity(0.7))
                .frame(width: nameWidth, alignment: .trailing)
                .padding(.trailing, 4)

            // Track area
            ZStack(alignment: .leading) {
                // Track line
                Rectangle()
                    .fill(Theme.ice.opacity(0.08))
                    .frame(height: 1)
                    .offset(y: 0)

                // Beat markers
                Canvas { context, size in
                    let beatLen = loopLength > 0 && beatsPerLoop > 0
                        ? CGFloat(loopLength) / CGFloat(beatsPerLoop) : 0

                    for beat in 0..<beatsPerLoop {
                        let x = beatLen > 0
                            ? CGFloat(beat) * beatLen / CGFloat(loopLength) * size.width
                            : 0
                        let isBar = beat % Transport.beatsPerBar == 0
                        context.fill(
                            Path(CGRect(x: x, y: 0, width: 1, height: size.height)),
                            with: .color(Theme.ice.opacity(isBar ? 0.2 : 0.08))
                        )
                    }
                }
                .frame(width: trackWidth, height: 20)

                // Hits — positioned Text views (not Canvas, for correct color support)
                ForEach(Array(layer.hits.enumerated()), id: \.offset) { _, hit in
                    let swungFrame = SwingMath.swungPosition(
                        hitFrame: hit.position,
                        swing: layer.swing,
                        sixteenthLength: sixteenthLength,
                        loopLength: loopLength
                    )
                    let xFrac = loopLength > 0 ? CGFloat(swungFrame) / CGFloat(loopLength) : 0
                    let cursorDist = abs(xFrac - cursorFraction)
                    let nearCursor = cursorDist < 0.01
                    let color = nearCursor ? Color.white : hitColor

                    Text(hitGlyph(velocity: hit.velocity))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(color.opacity(hitOpacity(velocity: hit.velocity)))
                        .position(x: xFrac * trackWidth, y: 10)
                }
                .frame(width: trackWidth, height: 20)

                // Playback cursor
                Rectangle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 1.5, height: 20)
                    .offset(x: cursorFraction * trackWidth)
            }
            .frame(width: trackWidth, height: 20)
        }
        .frame(height: 22)
    }
}
```

- [ ] **Step 3: Build to verify both files compile**

Run: `cd ~/god/GOD && swift build 2>&1 | tail -5`
Expected: Build succeeded

- [ ] **Step 4: Commit**

```bash
cd ~/god && git add GOD/GOD/Views/TriggerMatrixView.swift GOD/GOD/Views/TriggerRowView.swift
git commit -m "feat: add TriggerMatrixView and TriggerRowView — crystalline hit visualization"
```

### Task 7: Integrate TriggerMatrixView into CanvasView

**Files:**
- Modify: `GOD/GOD/Views/CanvasView.swift`

- [ ] **Step 1: Restructure CanvasView layout**

Replace the entire body of `CanvasView` in `GOD/GOD/Views/CanvasView.swift`:

```swift
struct CanvasView: View {
    @ObservedObject var engine: GodEngine
    @ObservedObject var interpreter: EngineEventInterpreter

    private var hasActiveRows: Bool {
        engine.layers.contains { !$0.hits.isEmpty || $0.padState == .red }
    }

    var body: some View {
        ZStack {
            Theme.canvasBg

            // Layer 1: Pad visual columns (background)
            PadVisualsLayer(
                interpreter: interpreter,
                isMuted: engine.layers.map(\.isMuted),
                isSustained: (0..<PadBank.padCount).map { i in
                    (engine.padBank.pads[i].sample?.durationMs ?? 0) > engine.loopDurationMs
                }
            )

            if hasActiveRows {
                // Compact layout: title top, trigger matrix middle, terminal bottom
                VStack(spacing: 0) {
                    // GOD title (compact)
                    GodTitleLayer(
                        isPlaying: engine.transport.isPlaying,
                        capture: engine.capture,
                        transport: engine.transport,
                        metronome: engine.metronome,
                        masterVolume: engine.masterVolume
                    )
                    .frame(maxHeight: 200)

                    // Trigger matrix
                    TriggerMatrixView(engine: engine)
                        .frame(maxHeight: .infinity)

                    // Terminal log
                    TerminalTextLayer(interpreter: interpreter)
                        .frame(maxHeight: 160)
                }
            } else {
                // Full layout: title + geometry fill canvas, terminal overlaid
                GodTitleLayer(
                    isPlaying: engine.transport.isPlaying,
                    capture: engine.capture,
                    transport: engine.transport,
                    metronome: engine.metronome,
                    masterVolume: engine.masterVolume
                )

                TerminalTextLayer(interpreter: interpreter)
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `cd ~/god/GOD && swift build 2>&1 | tail -5`
Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
cd ~/god && git add GOD/GOD/Views/CanvasView.swift
git commit -m "feat: integrate TriggerMatrixView into CanvasView with compact/full layout toggle"
```

### Task 8: Crystal color treatment for terminal log

**Files:**
- Modify: `GOD/GOD/Views/TerminalTextLayer.swift:51-59` (lineColor function)

- [ ] **Step 1: Update terminal line colors**

In `GOD/GOD/Views/TerminalTextLayer.swift`, replace the `lineColor` function:

```swift
private func lineColor(_ kind: LineKind) -> Color {
    switch kind {
    case .system:    return Theme.ice
    case .transport: return Theme.ice
    case .hit:       return Theme.orange
    case .state:     return Color.white
    case .capture:   return Theme.orange
    case .browse:    return Theme.ice
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `cd ~/god/GOD && swift build 2>&1 | tail -5`
Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
cd ~/god && git add GOD/GOD/Views/TerminalTextLayer.swift
git commit -m "feat: crystal color treatment for terminal log — ice blue system, orange hits"
```

### Task 9: Add swing display to CCPanelView

**Files:**
- Modify: `GOD/GOD/Views/CCPanelView.swift`

- [ ] **Step 1: Add swing row to CCPanelView**

Find the section in `CCPanelView.swift` that shows per-pad controls (volume, pan, HP, LP) and add a swing row after the LP cutoff row. The row should display:

```swift
// Swing
HStack {
    Text("swing")
        .foregroundColor(Theme.ice.opacity(0.5))
    Spacer()
    let swingPct = Int((engine.layers[engine.activePadIndex].swing - 0.5) / 0.25 * 100)
    Text("\(swingPct)%")
        .foregroundColor(swingPct > 0 ? Theme.orange : Color.white)
}
.font(Theme.monoSmall)
```

- [ ] **Step 2: Build to verify**

Run: `cd ~/god/GOD && swift build 2>&1 | tail -5`
Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
cd ~/god && git add GOD/GOD/Views/CCPanelView.swift
git commit -m "feat: show per-pad swing percentage in CCPanelView"
```

### Task 10: Final integration test and build

**Files:** None new — verification only

- [ ] **Step 1: Run full test suite**

Run: `cd ~/god/GOD && swift test 2>&1 | tail -20`
Expected: All tests PASS

- [ ] **Step 2: Run full build**

Run: `cd ~/god/GOD && swift build 2>&1 | tail -5`
Expected: Build succeeded

- [ ] **Step 3: Launch and smoke test**

Run: `cd ~/god/GOD && .build/arm64-apple-macosx/debug/GOD`

Manual verification:
1. Press SPACE to start loop
2. Press F to arm a pad, play some hits via MIDI
3. Verify hits appear in the trigger matrix as red crystals
4. After loop wrap, crystals turn orange (alive)
5. Press V to increase swing — watch hits shift right in the matrix
6. Press Shift+V to decrease swing back to 0%
7. Arm a second pad, verify it gets its own row
8. Press C to clear a pad — row fades out
9. Verify terminal log has ice blue / orange coloring

- [ ] **Step 4: Commit any fixes found during smoke test**

If fixes needed, commit them individually with descriptive messages.

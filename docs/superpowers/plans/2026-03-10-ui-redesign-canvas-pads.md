# UI Redesign: Canvas, Pads & Engine Terminal — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the split-panel layout with a unified canvas (visual columns + engine terminal text), horizontal pad strip with CC readout, and WASD navigation.

**Architecture:** An EngineEventInterpreter consumes per-hit data and state diffs from GodEngine at ~30Hz, producing typed events. Two consumers render those events: a terminal text formatter (scrolling lines) and a visual renderer (per-pad glow columns). Both render into a single composited canvas view.

**Tech Stack:** Swift, SwiftUI, AVFoundation (unchanged audio pipeline)

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `GOD/GOD/Engine/EngineEventInterpreter.swift` | Event types, state diffing, hit processing, text formatting |
| Create | `GOD/GOD/Views/CanvasView.swift` | Unified zone: visual columns (bg) + ASCII title (mid) + terminal text (fg) |
| Create | `GOD/GOD/Views/PadStripView.swift` | Horizontal 8-pad strip, active pad CC readout, signal meters |
| Create | `GOD/Tests/EngineEventInterpreterTests.swift` | Tests for event generation and text formatting |
| Modify | `GOD/GOD/Engine/GodEngine.swift` | Expose pending hits to interpreter, remove `stateSnapshot()`, stop audio thread overwriting `activePadIndex`, repurpose `onStateChanged` |
| Modify | `GOD/GOD/ContentView.swift` | New layout stack, WASD/C key bindings, remove old deps |
| Modify | `GOD/GOD/Views/TransportView.swift` | Single-line horizontal bar with capture status + loop bar |
| Modify | `GOD/GOD/Views/Theme.swift` | ASCII GOD art, canvas colors, new font sizes |
| Modify | `GOD/GOD/Views/KeyReferenceOverlay.swift` | Updated shortcut list |
| Modify | `GOD/GOD/GODApp.swift` | Remove LLMManager/TerminalState, wire interpreter |
| Remove | `GOD/GOD/Views/ChannelRowView.swift` | Replaced by PadStripView |
| Remove | `GOD/GOD/Views/GenesisTerminalView.swift` | Replaced by CanvasView |
| Remove | `GOD/GOD/Views/SignalMeterView.swift` | Signal meters inline in PadStripView |
| Remove | `GOD/GOD/Views/LoopBarView.swift` | Loop bar inline in TransportView |
| Remove | `GOD/GOD/Views/CaptureIndicatorView.swift` | Capture status inline in TransportView |
| Remove | `GOD/GOD/Views/TipView.swift` | Replaced by engine terminal |
| Remove | `GOD/GOD/Models/Tips.swift` | No longer needed |
| Remove | `GOD/GOD/Engine/LLMManager.swift` | Replaced by EngineEventInterpreter |
| Remove | `GOD/GOD/Engine/StateSnapshot.swift` | Was for LLM feed |
| Remove | `GOD/Tests/LLMManagerTests.swift` | No longer needed |
| Remove | `GOD/Tests/StateSnapshotTests.swift` | No longer needed |
| Remove | `GOD/Tests/TipsTests.swift` | No longer needed |

---

## Chunk 1: Engine Event Interpreter (core system)

### Task 1: EngineEvent type and formatting helpers

**Files:**
- Create: `GOD/GOD/Engine/EngineEventInterpreter.swift`
- Create: `GOD/Tests/EngineEventInterpreterTests.swift`

- [ ] **Step 1: Write failing tests for frequency formatting**

```swift
// GOD/Tests/EngineEventInterpreterTests.swift
import Testing
@testable import GOD

@Test func formatFrequencyBelowThousand() {
    #expect(EngineEventInterpreter.formatFrequency(340) == "340Hz")
    #expect(EngineEventInterpreter.formatFrequency(20) == "20Hz")
    #expect(EngineEventInterpreter.formatFrequency(999) == "999Hz")
}

@Test func formatFrequencyAboveThousand() {
    #expect(EngineEventInterpreter.formatFrequency(1000) == "1.0kHz")
    #expect(EngineEventInterpreter.formatFrequency(4200) == "4.2kHz")
    #expect(EngineEventInterpreter.formatFrequency(20000) == "20.0kHz")
}

@Test func formatPan() {
    #expect(EngineEventInterpreter.formatPan(0.5) == "C")
    #expect(EngineEventInterpreter.formatPan(0.0) == "L50")
    #expect(EngineEventInterpreter.formatPan(1.0) == "R50")
    #expect(EngineEventInterpreter.formatPan(0.35) == "L15")
    #expect(EngineEventInterpreter.formatPan(0.65) == "R15")
}

@Test func formatDuration() {
    #expect(EngineEventInterpreter.formatDuration(100) == ".1s")
    #expect(EngineEventInterpreter.formatDuration(80) == ".08s")
    #expect(EngineEventInterpreter.formatDuration(14200) == "14.2s")
    #expect(EngineEventInterpreter.formatDuration(1000) == "1.0s")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/god/GOD && swift test --filter EngineEventInterpreter 2>&1 | tail -20`
Expected: Compilation error — `EngineEventInterpreter` not found

- [ ] **Step 3: Implement EngineEvent enum and formatting helpers**

```swift
// GOD/GOD/Engine/EngineEventInterpreter.swift
import Foundation

struct TerminalLine: Identifiable {
    let id = UUID()
    let text: String
    let timestamp: Date = Date()
}

class EngineEventInterpreter: ObservableObject {
    @Published var lines: [TerminalLine] = []
    @Published var padIntensities: [Float] = Array(repeating: 0, count: 8)

    private let maxLines = 30

    // Previous state for diffing
    private var prevMuted: [Bool] = Array(repeating: false, count: 8)
    private var prevVolumes: [Float] = Array(repeating: 1.0, count: 8)
    private var prevPans: [Float] = Array(repeating: 0.5, count: 8)
    private var prevHP: [Float] = Array(repeating: 20.0, count: 8)
    private var prevLP: [Float] = Array(repeating: 20000.0, count: 8)
    private var prevPlaying: Bool = false
    private var prevCaptureState: String = "idle"
    private var loopHitCounts: [Int] = Array(repeating: 0, count: 8)
    private var loopHitVelocities: [[Int]] = Array(repeating: [], count: 8)

    // Decay constants
    private static let shortDecay: Float = 0.92
    private static let sustainDecay: Float = 0.98

    func appendLine(_ text: String) {
        let line = TerminalLine(text: text)
        lines.append(line)
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
    }

    func processHits(_ hits: [(padIndex: Int, position: Int, velocity: Int)],
                     padBank: PadBank, loopDurationMs: Double) {
        // Must reassign array (not mutate elements) to trigger @Published
        var intensities = padIntensities
        for hit in hits {
            let pad = padBank.pads[hit.padIndex]
            let name = pad.sample?.name ?? pad.name
            let durationMs = pad.sample?.durationMs ?? 0

            // Update visual intensity
            let velNorm = Float(hit.velocity) / 127.0
            intensities[hit.padIndex] = min(1.0, velNorm)

            // Track for loop summary
            loopHitCounts[hit.padIndex] += 1
            loopHitVelocities[hit.padIndex].append(hit.velocity)

            // Format hit event line
            let dur = Self.formatDuration(durationMs)
            let velDesc = hit.velocity > 90 ? " — hard hit" : ""
            appendLine("\(name.lowercased()) \(dur) — vel \(hit.velocity)\(velDesc)")
        }
        padIntensities = intensities
    }

    func processStateDiff(layers: [Layer], transport: Transport, capture: GodCapture,
                          padBank: PadBank, masterVolume: Float) {
        // Transport state changes
        if transport.isPlaying && !prevPlaying {
            let loopSec = Double(transport.loopLengthFrames) / Transport.sampleRate
            appendLine("▶ loop start — \(transport.barCount) bars @ \(transport.bpm)bpm (\(String(format: "%.1f", loopSec))s)")
        } else if !transport.isPlaying && prevPlaying {
            appendLine("■ stopped")
        }
        prevPlaying = transport.isPlaying

        // Mute changes
        for i in 0..<8 {
            if layers[i].isMuted != prevMuted[i] {
                let name = padBank.pads[i].sample?.name ?? padBank.pads[i].name
                if layers[i].isMuted {
                    appendLine("pad \(i + 1) \(name.lowercased()) muted ○")
                    var intensities = padIntensities
                    intensities[i] = 0
                    padIntensities = intensities
                } else {
                    appendLine("pad \(i + 1) \(name.lowercased()) unmuted ●")
                }
                prevMuted[i] = layers[i].isMuted
            }
        }

        // CC changes — only emit when value actually changes
        for i in 0..<8 {
            if abs(layers[i].volume - prevVolumes[i]) > 0.01 {
                appendLine("pad \(i + 1) vol → \(Int(layers[i].volume * 100))%")
                prevVolumes[i] = layers[i].volume
            }
            if abs(layers[i].pan - prevPans[i]) > 0.01 {
                appendLine("pad \(i + 1) pan → \(Self.formatPan(layers[i].pan))")
                prevPans[i] = layers[i].pan
            }
            if abs(layers[i].hpCutoff - prevHP[i]) > 1 {
                appendLine("pad \(i + 1) HP → \(Self.formatFrequency(layers[i].hpCutoff))")
                prevHP[i] = layers[i].hpCutoff
            }
            if abs(layers[i].lpCutoff - prevLP[i]) > 1 {
                appendLine("pad \(i + 1) LP → \(Self.formatFrequency(layers[i].lpCutoff))")
                prevLP[i] = layers[i].lpCutoff
            }
        }

        // Capture state
        let captureStr: String
        switch capture.state {
        case .idle: captureStr = "idle"
        case .armed: captureStr = "armed"
        case .recording: captureStr = "recording"
        }
        if captureStr != prevCaptureState {
            switch capture.state {
            case .armed: appendLine("capture armed — next loop boundary")
            case .recording: appendLine("capture recording ◉")
            case .idle:
                if prevCaptureState == "recording" {
                    appendLine("capture saved")
                }
            }
            prevCaptureState = captureStr
        }
    }

    func onLoopBoundary(layers: [Layer], padBank: PadBank, loopDurationMs: Double) {
        appendLine("loop boundary — wrap")

        // Emit layer summaries for pads with hits
        for i in 0..<8 where loopHitCounts[i] > 0 {
            let name = padBank.pads[i].sample?.name ?? padBank.pads[i].name
            let count = loopHitCounts[i]
            let vels = loopHitVelocities[i]
            let velMin = vels.min() ?? 0
            let velMax = vels.max() ?? 0
            let spread = velMax - velMin
            let spreadDesc = spread < 20 ? "tight" : "varying"
            let sampleMs = padBank.pads[i].sample?.durationMs ?? 0

            if sampleMs > loopDurationMs {
                // Long loop — flag it
                let dur = Self.formatDuration(sampleMs)
                // Find other active pads
                let others = (0..<8).filter { $0 != i && loopHitCounts[$0] > 0 }
                    .map { padBank.pads[$0].sample?.name.lowercased() ?? padBank.pads[$0].name.lowercased() }
                let onTop = others.isEmpty ? "" : " on top of \(others.joined(separator: ", "))"
                appendLine("\(name.lowercased()) loop int \(dur)\(onTop) (\(count) hits, \(spreadDesc) vel)")
            } else {
                appendLine("\(name.lowercased()) (\(count) hits, \(spreadDesc) vel \(velMin)-\(velMax))")
            }
        }

        // Reset loop counters
        loopHitCounts = Array(repeating: 0, count: 8)
        loopHitVelocities = Array(repeating: [], count: 8)
    }

    // Track which pads have active voices (set by engine)
    var activePadVoices: Set<Int> = []

    func tickVisuals() {
        // Must reassign array (not mutate elements) to trigger @Published
        var updated = padIntensities
        for i in 0..<8 {
            if activePadVoices.contains(i) {
                // Sustained: hold intensity, slow decay
                updated[i] = max(updated[i] * Self.sustainDecay, 0.3)
            } else if updated[i] > 0.01 {
                updated[i] *= Self.shortDecay
            } else {
                updated[i] = 0
            }
        }
        padIntensities = updated
    }

    // MARK: - Formatting helpers

    static func formatFrequency(_ hz: Float) -> String {
        if hz >= 1000 {
            return String(format: "%.1fkHz", hz / 1000.0)
        }
        return "\(Int(hz))Hz"
    }

    static func formatPan(_ pan: Float) -> String {
        if abs(pan - 0.5) < 0.01 { return "C" }
        if pan < 0.5 {
            let pct = Int((0.5 - pan) * 100)
            return "L\(pct)"
        }
        let pct = Int((pan - 0.5) * 100)
        return "R\(pct)"
    }

    static func formatDuration(_ ms: Double) -> String {
        let sec = ms / 1000.0
        if sec < 1.0 {
            // Show as .XXs — strip leading zero
            let formatted = String(format: "%.2f", sec)
            let trimmed = formatted.hasPrefix("0") ? String(formatted.dropFirst()) : formatted
            // Remove trailing zero: .10 -> .1, but keep .08
            if trimmed.hasSuffix("0") && !trimmed.hasSuffix(".0") {
                return String(trimmed.dropLast()) + "s"
            }
            return trimmed + "s"
        }
        return String(format: "%.1f", sec) + "s"
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/god/GOD && swift test --filter EngineEventInterpreter 2>&1 | tail -20`
Expected: All 4 tests pass

- [ ] **Step 5: Write tests for hit processing and state diff events**

```swift
// Append to GOD/Tests/EngineEventInterpreterTests.swift

@Test func hitEventGeneratesTerminalLine() {
    let interpreter = EngineEventInterpreter()
    var bank = PadBank()
    let sample = Sample(name: "kick", left: [0.1, 0.2], right: [0.1, 0.2], sampleRate: 44100)
    bank.assign(sample: sample, toPad: 0)

    interpreter.processHits(
        [(padIndex: 0, position: 0, velocity: 112)],
        padBank: bank, loopDurationMs: 8000
    )

    #expect(interpreter.lines.count == 1)
    #expect(interpreter.lines[0].text.contains("kick"))
    #expect(interpreter.lines[0].text.contains("vel 112"))
}

@Test func hitEventSetsIntensity() {
    let interpreter = EngineEventInterpreter()
    var bank = PadBank()
    let sample = Sample(name: "kick", left: [0.1], right: [0.1], sampleRate: 44100)
    bank.assign(sample: sample, toPad: 0)

    interpreter.processHits(
        [(padIndex: 0, position: 0, velocity: 127)],
        padBank: bank, loopDurationMs: 8000
    )

    #expect(interpreter.padIntensities[0] == 1.0)
}

@Test func hardHitFlagged() {
    let interpreter = EngineEventInterpreter()
    var bank = PadBank()
    let sample = Sample(name: "snare", left: [0.1], right: [0.1], sampleRate: 44100)
    bank.assign(sample: sample, toPad: 1)

    interpreter.processHits(
        [(padIndex: 1, position: 0, velocity: 127)],
        padBank: bank, loopDurationMs: 8000
    )

    #expect(interpreter.lines[0].text.contains("hard hit"))
}

@Test func muteChangeEmitsEvent() {
    let interpreter = EngineEventInterpreter()
    var layers = (0..<8).map { Layer(index: $0, name: "PAD \($0 + 1)") }
    layers[3].isMuted = true

    interpreter.processStateDiff(
        layers: layers,
        transport: Transport(),
        capture: GodCapture(),
        padBank: PadBank(),
        masterVolume: 1.0
    )

    #expect(interpreter.lines.contains { $0.text.contains("muted") })
}

@Test func ccChangeEmitsEvent() {
    let interpreter = EngineEventInterpreter()
    var layers = (0..<8).map { Layer(index: $0, name: "PAD \($0 + 1)") }

    // First call establishes baseline
    interpreter.processStateDiff(layers: layers, transport: Transport(),
                                  capture: GodCapture(), padBank: PadBank(), masterVolume: 1.0)

    // Change volume on pad 0
    layers[0].volume = 0.72
    interpreter.processStateDiff(layers: layers, transport: Transport(),
                                  capture: GodCapture(), padBank: PadBank(), masterVolume: 1.0)

    #expect(interpreter.lines.contains { $0.text.contains("vol → 72%") })
}

@Test func loopBoundarySummary() {
    let interpreter = EngineEventInterpreter()
    var bank = PadBank()
    let sample = Sample(name: "hats", left: [0.1], right: [0.1], sampleRate: 44100)
    bank.assign(sample: sample, toPad: 2)

    // Simulate 4 hits during the loop
    interpreter.processHits([
        (padIndex: 2, position: 0, velocity: 95),
        (padIndex: 2, position: 1000, velocity: 100),
        (padIndex: 2, position: 2000, velocity: 98),
        (padIndex: 2, position: 3000, velocity: 104),
    ], padBank: bank, loopDurationMs: 8000)

    let layers = (0..<8).map { Layer(index: $0, name: "PAD \($0 + 1)") }
    interpreter.onLoopBoundary(layers: layers, padBank: bank, loopDurationMs: 8000)

    // Should have 4 hit lines + 1 summary line
    let summaryLine = interpreter.lines.last!.text
    #expect(summaryLine.contains("hats"))
    #expect(summaryLine.contains("4 hits"))
    #expect(summaryLine.contains("tight"))
}

@Test func visualDecay() {
    let interpreter = EngineEventInterpreter()
    interpreter.padIntensities[0] = 1.0

    interpreter.tickVisuals()
    #expect(interpreter.padIntensities[0] < 1.0)
    #expect(interpreter.padIntensities[0] > 0.9)

    // After many ticks it should decay to ~0
    for _ in 0..<100 {
        interpreter.tickVisuals()
    }
    #expect(interpreter.padIntensities[0] == 0)
}

@Test func transportStartEmitsEvent() {
    let interpreter = EngineEventInterpreter()
    var transport = Transport()
    transport.isPlaying = true

    interpreter.processStateDiff(
        layers: (0..<8).map { Layer(index: $0, name: "PAD \($0 + 1)") },
        transport: transport,
        capture: GodCapture(),
        padBank: PadBank(),
        masterVolume: 1.0
    )

    #expect(interpreter.lines.contains { $0.text.contains("loop start") })
    #expect(interpreter.lines.contains { $0.text.contains("120bpm") })
}

@Test func captureArmedEmitsEvent() {
    let interpreter = EngineEventInterpreter()
    var capture = GodCapture()
    capture.toggle() // idle → armed

    interpreter.processStateDiff(
        layers: (0..<8).map { Layer(index: $0, name: "PAD \($0 + 1)") },
        transport: Transport(),
        capture: capture,
        padBank: PadBank(),
        masterVolume: 1.0
    )

    #expect(interpreter.lines.contains { $0.text.contains("capture armed") })
}

@Test func loopBoundaryWrapEvent() {
    let interpreter = EngineEventInterpreter()
    let layers = (0..<8).map { Layer(index: $0, name: "PAD \($0 + 1)") }
    interpreter.onLoopBoundary(layers: layers, padBank: PadBank(), loopDurationMs: 8000)

    #expect(interpreter.lines.contains { $0.text.contains("loop boundary — wrap") })
}

@Test func sustainedDecaySlowerThanShort() {
    let interpreter = EngineEventInterpreter()
    interpreter.padIntensities = Array(repeating: 1.0, count: 8)
    interpreter.activePadVoices = [0] // pad 0 has active voice

    // Tick 10 times
    for _ in 0..<10 {
        interpreter.tickVisuals()
    }

    // Pad 0 (sustained) should decay slower than pad 1 (short)
    #expect(interpreter.padIntensities[0] > interpreter.padIntensities[1])
}

@Test func maxLinesRespected() {
    let interpreter = EngineEventInterpreter()
    for i in 0..<50 {
        interpreter.appendLine("line \(i)")
    }
    #expect(interpreter.lines.count == 30)
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd ~/god/GOD && swift test --filter EngineEventInterpreter 2>&1 | tail -20`
Expected: All 16 tests pass

- [ ] **Step 7: Commit**

```bash
git add GOD/GOD/Engine/EngineEventInterpreter.swift GOD/Tests/EngineEventInterpreterTests.swift
git commit -m "feat: add EngineEventInterpreter with event types and formatting"
```

---

### Task 2: Clean up removed files and wire interpreter into GodEngine

**Files:**
- Remove: `GOD/GOD/Engine/LLMManager.swift`, `GOD/GOD/Engine/StateSnapshot.swift`, `GOD/Tests/LLMManagerTests.swift`, `GOD/Tests/StateSnapshotTests.swift`, `GOD/Tests/TipsTests.swift`, `GOD/GOD/Models/Tips.swift`
- Modify: `GOD/GOD/Engine/GodEngine.swift`

Removing these files early keeps the build green throughout all subsequent tasks.

- [ ] **Step 1: Delete files that reference `stateSnapshot` and LLM**

```bash
cd ~/god
rm GOD/GOD/Engine/LLMManager.swift \
   GOD/GOD/Engine/StateSnapshot.swift \
   GOD/GOD/Models/Tips.swift \
   GOD/Tests/LLMManagerTests.swift \
   GOD/Tests/StateSnapshotTests.swift \
   GOD/Tests/TipsTests.swift
```

- [ ] **Step 2: Modify GodEngine — add interpreter, remove stateSnapshot, fix activePadIndex race**

Changes to `GodEngine.swift`:

1. Add interpreter property (after line 16):
```swift
var interpreter: EngineEventInterpreter?
```

2. Delete the `stateSnapshot()` method (lines 100-142). Keep `loopDurationMs` (lines 96-98) — it already sits above `stateSnapshot`.

3. Remove `var onStateChanged: (() -> Void)?` (line 16) and `self.onStateChanged?()` (line 353).

4. **Fix activePadIndex race:** In the `DispatchQueue.main.async` UI update block (around line 332-354), **remove** the line `self.activePadIndex = activePad`. The audio thread should NOT overwrite `activePadIndex` — it's now controlled by WASD keyboard navigation. Instead, sync the audio thread's copy FROM the UI:

Replace `let activePad = audioActivePadIndex` (line 324) with:
```swift
audioActivePadIndex = activePadIndex  // read from UI, don't write to UI
```
And delete the line `self.activePadIndex = activePad` from the dispatch block.

5. **Feed interpreter** — add at the end of the `DispatchQueue.main.async` block:
```swift
if let interp = self.interpreter {
    // Track active voices per pad
    let activeVoicePads = Set(self.voices.filter { $0.padIndex >= 0 }.map(\.padIndex))
    interp.activePadVoices = activeVoicePads

    interp.processHits(hits, padBank: self.padBank, loopDurationMs: self.loopDurationMs)
    interp.processStateDiff(
        layers: self.layers,
        transport: self.transport,
        capture: self.capture,
        padBank: self.padBank,
        masterVolume: self.masterVolume
    )
    interp.tickVisuals()
}
```

6. **Feed loop boundary** — in `processBlock`, inside the existing `if wrapped { DispatchQueue.main.async { ... } }` block (around line 310), add after `self.capture.state = captureState`:
```swift
self.interpreter?.onLoopBoundary(
    layers: self.layers,
    padBank: self.padBank,
    loopDurationMs: self.loopDurationMs
)
```

- [ ] **Step 3: Run full test suite**

Run: `cd ~/god/GOD && swift test 2>&1 | tail -30`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add -u
git commit -m "refactor: remove LLM/StateSnapshot/Tips, wire interpreter into GodEngine"
```

---

## Chunk 2: Views — Theme, Transport, Pads, Canvas

### Task 3: Update Theme with ASCII GOD art and new colors

**Files:**
- Modify: `GOD/GOD/Views/Theme.swift`

- [ ] **Step 1: Add ASCII art and canvas colors to Theme**

Add to the end of `Theme.swift`:

```swift
// Canvas
static let canvasBg = Color(red: 0.075, green: 0.071, blue: 0.063)  // #131210

// ASCII GOD title — D clearly distinct from O
static let godArtIdle = """
 ██████   ██████  ██████▄
██       ██    ██ ██    ██
██  ████ ██    ██ ██    ██
██    ██ ██    ██ ██    ██
 ██████   ██████  ██████▀
"""

static let godSubtitle = "GENESIS ON DISK"

// Charcoal for idle title
static let charcoal = Color(red: 0.165, green: 0.157, blue: 0.145)  // #2a2825
```

- [ ] **Step 2: Run build to verify no compilation errors**

Run: `cd ~/god/GOD && swift build 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add GOD/GOD/Views/Theme.swift
git commit -m "feat: add ASCII GOD art and canvas colors to Theme"
```

---

### Task 4: Redesign TransportView as single horizontal bar

**Files:**
- Modify: `GOD/GOD/Views/TransportView.swift`

- [ ] **Step 1: Rewrite TransportView as a single-line horizontal bar**

Replace the entire body of `TransportView.swift`:

```swift
import SwiftUI

struct TransportView: View {
    @ObservedObject var engine: GodEngine

    private var currentBeat: Int {
        let beatLength = engine.metronome.beatLengthFrames(
            bpm: engine.transport.bpm,
            sampleRate: Transport.sampleRate
        )
        guard beatLength > 0 else { return 1 }
        return (engine.transport.position / beatLength) % (engine.transport.barCount * 4) + 1
    }

    private var loopProgress: Double {
        let loopLen = engine.transport.loopLengthFrames
        guard loopLen > 0 else { return 0 }
        return Double(engine.transport.position) / Double(loopLen)
    }

    private var captureText: String {
        switch engine.capture.state {
        case .idle: return "○ GOD"
        case .armed: return "◉ GOD — armed"
        case .recording: return "◉ GOD — recording"
        }
    }

    private var captureColor: Color {
        switch engine.capture.state {
        case .idle: return Theme.text
        case .armed, .recording: return Theme.orange
        }
    }

    @State private var captureOpacity: Double = 1.0

    var body: some View {
        HStack(spacing: 16) {
            // Play state
            Text(engine.transport.isPlaying ? "▶" : "■")
                .foregroundColor(engine.transport.isPlaying ? Theme.blue : Theme.subtle)
                .font(Theme.monoLarge)

            // BPM
            Text("\(engine.transport.bpm)")
                .foregroundColor(engine.transport.isPlaying ? Theme.text : Theme.subtle)
                .font(.system(size: 18, design: .monospaced).bold())
            Text("bpm")
                .foregroundColor(Theme.subtle)
                .font(Theme.monoSmall)

            // Bar count
            HStack(spacing: 2) {
                Text("[").foregroundColor(Theme.blue)
                Text("\(engine.transport.barCount)").foregroundColor(Theme.text)
                Text("]").foregroundColor(Theme.blue)
                Text("bars").foregroundColor(Theme.subtle)
            }
            .font(Theme.monoSmall)

            // Metronome
            Text("♩ \(engine.metronome.isOn ? "on" : "off")")
                .foregroundColor(engine.metronome.isOn ? Theme.blue : Theme.subtle)
                .font(Theme.monoSmall)

            // Beat counter
            if engine.transport.isPlaying {
                Text("beat \(currentBeat)")
                    .foregroundColor(Theme.blue)
                    .font(Theme.monoSmall)
            }

            Spacer()

            // Capture status
            Text(captureText)
                .foregroundColor(captureColor)
                .font(Theme.monoSmall)
                .opacity(engine.capture.state == .recording ? captureOpacity : 1.0)
                .animation(
                    engine.capture.state == .recording
                        ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                        : .default,
                    value: engine.capture.state == .recording
                )
                .onChange(of: engine.capture.state == .recording) { _, isRecording in
                    captureOpacity = isRecording ? 0.5 : 1.0
                }

            // Master volume
            Text("master \(Int(engine.masterVolume * 100))%")
                .foregroundColor(Theme.subtle)
                .font(Theme.monoSmall)

            // Inline loop progress bar
            GeometryReader { _ in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.subtle.opacity(0.3))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.blue)
                        .frame(width: 80 * loopProgress)
                }
            }
            .frame(width: 80, height: 3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.122, green: 0.118, blue: 0.106))  // #1f1e1b
    }
}
```

- [ ] **Step 2: Run build**

Run: `cd ~/god/GOD && swift build 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add GOD/GOD/Views/TransportView.swift
git commit -m "feat: redesign TransportView as single horizontal bar"
```

---

### Task 5: Create PadStripView

**Files:**
- Create: `GOD/GOD/Views/PadStripView.swift`

- [ ] **Step 1: Create horizontal pad strip with CC readout**

```swift
// GOD/GOD/Views/PadStripView.swift
import SwiftUI

struct PadStripView: View {
    @ObservedObject var engine: GodEngine
    @ObservedObject var interpreter: EngineEventInterpreter

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<8, id: \.self) { index in
                PadView(
                    index: index,
                    pad: engine.padBank.pads[index],
                    layer: engine.layers[index],
                    isActive: engine.activePadIndex == index,
                    triggered: engine.channelTriggered[index],
                    signalLevel: engine.channelSignalLevels[index],
                    intensity: interpreter.padIntensities[index]
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

struct PadView: View {
    let index: Int
    let pad: Pad
    let layer: Layer
    let isActive: Bool
    let triggered: Bool
    let signalLevel: Float
    let intensity: Float

    private var borderColor: Color {
        if layer.isMuted { return Theme.subtle }
        if intensity > 0.5 && (pad.sample?.durationMs ?? 0) > 1000 { return Theme.orange }
        return Theme.blue
    }

    var body: some View {
        VStack(spacing: 3) {
            // Pad number
            Text("\(index + 1)")
                .font(.system(size: 14, design: .monospaced).bold())
                .foregroundColor(triggered ? Theme.orange : (isActive ? Theme.blue : Theme.subtle))

            // Sample name
            Text(pad.sample?.name.uppercased().prefix(6) ?? "—")
                .font(Theme.monoTiny)
                .foregroundColor(layer.isMuted ? Theme.subtle : Color(white: 0.7))
                .lineLimit(1)

            // Signal meter
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Theme.subtle.opacity(0.3))
                    RoundedRectangle(cornerRadius: 1)
                        .fill(borderColor)
                        .frame(width: geo.size.width * CGFloat(signalLevel))
                }
            }
            .frame(height: 3)

            // CC values on active pad
            if isActive {
                VStack(spacing: 1) {
                    CCLabel(name: "vol", value: "\(Int(layer.volume * 100))%", highlight: false)
                    CCLabel(name: "pan", value: EngineEventInterpreter.formatPan(layer.pan), highlight: false)
                    CCLabel(name: "HP", value: EngineEventInterpreter.formatFrequency(layer.hpCutoff),
                            highlight: layer.hpCutoff > 21)
                    CCLabel(name: "LP", value: EngineEventInterpreter.formatFrequency(layer.lpCutoff),
                            highlight: layer.lpCutoff < 19999)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .layoutPriority(isActive ? 1.4 : 1.0)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(layer.isMuted
                      ? Color(red: 0.118, green: 0.114, blue: 0.102)  // dimmer
                      : Color(red: 0.145, green: 0.137, blue: 0.125)) // #252320
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.orange.opacity(triggered ? 0.15 : 0))
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(borderColor)
                .frame(height: 2)
        }
        .shadow(color: isActive ? Theme.blue.opacity(0.25) : .clear, radius: 8)
        .opacity(layer.isMuted ? 0.5 : 1.0)
    }
}

struct CCLabel: View {
    let name: String
    let value: String
    let highlight: Bool

    var body: some View {
        HStack(spacing: 2) {
            Text(name)
                .foregroundColor(Theme.subtle)
            Text(value)
                .foregroundColor(highlight ? Theme.orange : Color(white: 0.7))
        }
        .font(.system(size: 7, design: .monospaced))
    }
}
```

- [ ] **Step 2: Run build**

Run: `cd ~/god/GOD && swift build 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add GOD/GOD/Views/PadStripView.swift
git commit -m "feat: add PadStripView with horizontal pads and CC readout"
```

---

### Task 6: Create CanvasView

**Files:**
- Create: `GOD/GOD/Views/CanvasView.swift`

- [ ] **Step 1: Create unified canvas with visual columns + ASCII title + terminal text**

```swift
// GOD/GOD/Views/CanvasView.swift
import SwiftUI

struct CanvasView: View {
    @ObservedObject var engine: GodEngine
    @ObservedObject var interpreter: EngineEventInterpreter

    var body: some View {
        ZStack {
            Theme.canvasBg

            // Layer 1: Pad visual columns (background)
            PadVisualsLayer(
                interpreter: interpreter,
                isMuted: engine.layers.map(\.isMuted),
                isSustained: (0..<8).map { i in
                    (engine.padBank.pads[i].sample?.durationMs ?? 0) > engine.loopDurationMs
                }
            )

            // Layer 2: ASCII GOD title (middle)
            GodTitleLayer(isPlaying: engine.transport.isPlaying)

            // Layer 3: Terminal text (foreground)
            if engine.transport.isPlaying {
                TerminalTextLayer(interpreter: interpreter)
            }
        }
    }
}

// MARK: - Visual columns rising from pads

struct PadVisualsLayer: View {
    @ObservedObject var interpreter: EngineEventInterpreter
    let isMuted: [Bool]
    let isSustained: [Bool]  // true if sample duration > loop length

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { i in
                    ZStack(alignment: .bottom) {
                        if !isMuted[i] && interpreter.padIntensities[i] > 0.01 {
                            let intensity = CGFloat(interpreter.padIntensities[i])
                            let height = geo.size.height * intensity
                            let color = isSustained[i] ? Theme.orange : Theme.blue

                            LinearGradient(
                                gradient: Gradient(colors: [
                                    color.opacity(Double(intensity) * 0.2),
                                    color.opacity(0.03),
                                    .clear
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                            .frame(height: height)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }
}

// MARK: - ASCII GOD title

struct GodTitleLayer: View {
    let isPlaying: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(Theme.godArtIdle)
                .font(.system(size: 12, design: .monospaced).bold())
                .foregroundColor(isPlaying ? Theme.blue : Theme.charcoal)
                .shadow(color: isPlaying ? Theme.blue.opacity(0.4) : .clear, radius: 20)
                .multilineTextAlignment(.center)

            if !isPlaying {
                Text(Theme.godSubtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.charcoal)
                    .tracking(4)

                Text("press SPACE to begin")
                    .font(Theme.monoTiny)
                    .foregroundColor(Theme.charcoal.opacity(0.6))
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - Terminal text overlay

struct TerminalTextLayer: View {
    @ObservedObject var interpreter: EngineEventInterpreter

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    Spacer(minLength: 100) // push text toward bottom

                    ForEach(Array(interpreter.lines.enumerated()), id: \.element.id) { index, line in
                        Text(line.text)
                            .font(Theme.monoTiny)
                            .foregroundColor(Theme.text)
                            .opacity(lineOpacity(index: index, total: interpreter.lines.count))
                            .id(line.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .onChange(of: interpreter.lines.count) { _, _ in
                if let last = interpreter.lines.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func lineOpacity(index: Int, total: Int) -> Double {
        guard total > 1 else { return 1.0 }
        let position = Double(index) / Double(total - 1)
        return 0.3 + 0.7 * position
    }
}
```

- [ ] **Step 2: Run build**

Run: `cd ~/god/GOD && swift build 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add GOD/GOD/Views/CanvasView.swift
git commit -m "feat: add CanvasView with visual columns, ASCII title, and terminal text"
```

---

## Chunk 3: Wiring — ContentView, GODApp, Cleanup

### Task 7: Rewrite ContentView and GODApp together

**Files:**
- Modify: `GOD/GOD/ContentView.swift`
- Modify: `GOD/GOD/GODApp.swift`

These two files must change together since ContentView's init signature changes.

- [ ] **Step 1: Rewrite ContentView**

Replace the entire `ContentView` struct (keep `KeyCaptureView`, `KeyCaptureRepresentable`, and `KeyLabel`):

```swift
struct ContentView: View {
    @ObservedObject var engine: GodEngine
    @ObservedObject var interpreter: EngineEventInterpreter
    @State private var showSetup = false
    @State private var showKeyReference = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            KeyCaptureRepresentable { keyCode, chars in
                handleKey(keyCode: keyCode, chars: chars)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 0) {
                // Transport bar
                TransportView(engine: engine)

                // Canvas (fills remaining space)
                CanvasView(engine: engine, interpreter: interpreter)

                // Pad strip
                PadStripView(engine: engine, interpreter: interpreter)

                // Hotkeys strip
                HStack(spacing: 12) {
                    KeyLabel(key: "SPC", action: "play")
                    KeyLabel(key: "G", action: "god")
                    KeyLabel(key: "A/D", action: "pad ←→")
                    KeyLabel(key: "W", action: "mute")
                    KeyLabel(key: "S", action: "—")
                    KeyLabel(key: "M", action: "metro")
                    KeyLabel(key: "↑↓", action: "bpm")
                    KeyLabel(key: "[]", action: "bars")
                    KeyLabel(key: "-+", action: "vol")
                    KeyLabel(key: "Z", action: "undo")
                    KeyLabel(key: "C", action: "clear")
                    KeyLabel(key: "T", action: "setup")
                    KeyLabel(key: "ESC", action: "stop")
                    KeyLabel(key: "?", action: "help")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color(red: 0.086, green: 0.082, blue: 0.075))  // #161513
            }

            if showKeyReference {
                KeyReferenceOverlay(isVisible: $showKeyReference)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .sheet(isPresented: $showSetup) {
            SetupView(engine: engine, isPresented: $showSetup)
                .frame(width: 500, height: 500)
        }
    }

    // macOS virtual key codes
    private enum Key {
        static let space: UInt16 = 49
        static let a: UInt16 = 0
        static let d: UInt16 = 2
        static let w: UInt16 = 13
        static let c: UInt16 = 8
        static let g: UInt16 = 5
        static let m: UInt16 = 46
        static let t: UInt16 = 17
        static let z: UInt16 = 6
        static let upArrow: UInt16 = 126
        static let downArrow: UInt16 = 125
        static let escape: UInt16 = 53
        static let leftBracket: UInt16 = 33
        static let rightBracket: UInt16 = 30
    }

    private func handleKey(keyCode: UInt16, chars: String?) {
        switch keyCode {
        case Key.space:
            engine.togglePlay()
        case Key.g:
            engine.toggleCapture()
        case Key.m:
            engine.toggleMetronome()
        case Key.t:
            showSetup = true
        case Key.a:
            // Navigate pad left (wrap)
            engine.activePadIndex = (engine.activePadIndex - 1 + 8) % 8
        case Key.d:
            // Navigate pad right (wrap)
            engine.activePadIndex = (engine.activePadIndex + 1) % 8
        case Key.w:
            // Toggle mute on active pad
            engine.toggleMute(layer: engine.activePadIndex)
        case Key.c:
            // Clear active pad layer
            engine.clearLayer(engine.activePadIndex)
        case Key.upArrow:
            engine.setBPM(engine.transport.bpm + 1)
        case Key.downArrow:
            engine.setBPM(engine.transport.bpm - 1)
        case Key.escape:
            engine.stop()
        case Key.leftBracket:
            engine.cycleBarCount(forward: false)
        case Key.rightBracket:
            engine.cycleBarCount(forward: true)
        case Key.z:
            engine.undoLastClear()
        default:
            break
        }

        if let c = chars?.first {
            switch c {
            case "?":
                showKeyReference.toggle()
            case "-":
                engine.adjustMasterVolume(-0.05)
            case "=", "+":
                engine.adjustMasterVolume(0.05)
            default: break
            }
        }
    }
}
```

- [ ] **Step 2: Rewrite GODApp.swift**

```swift
import SwiftUI
import AppKit
import os

private let logger = Logger(subsystem: "com.god.app", category: "GODApp")

@main
struct GODApp: App {
    @StateObject private var engine = GodEngine()
    @StateObject private var interpreter = EngineEventInterpreter()
    @State private var audioManager: AudioManager?
    @State private var midiManager: MIDIManager?

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(engine: engine, interpreter: interpreter)
                .onAppear {
                    startManagers()
                    NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)
    }

    private func startManagers() {
        ensureSpliceFolders()

        try? engine.padBank.loadConfig()
        engine.padBank.loadFromSpliceFolders()
        try? engine.padBank.save()

        // Wire interpreter
        engine.interpreter = interpreter

        let audio = AudioManager(engine: engine)
        do {
            try audio.start()
        } catch {
            logger.error("Audio engine failed to start: \(error.localizedDescription)")
        }
        audioManager = audio

        let midi = MIDIManager(ringBuffer: engine.midiRingBuffer)
        midi.start()
        midiManager = midi
    }

    private func ensureSpliceFolders() {
        let fm = FileManager.default
        for name in PadBank.spliceFolderNames {
            let url = PadBank.spliceBasePath.appendingPathComponent(name)
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
```

- [ ] **Step 3: Run build**

Run: `cd ~/god/GOD && swift build 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add GOD/GOD/ContentView.swift GOD/GOD/GODApp.swift
git commit -m "feat: rewire ContentView and GODApp for new layout with WASD and interpreter"
```

---

### Task 8: Update KeyReferenceOverlay

**Files:**
- Modify: `GOD/GOD/Views/KeyReferenceOverlay.swift`

- [ ] **Step 1: Update shortcuts list**

Replace the `shortcuts` array:

```swift
private let shortcuts: [(key: String, action: String)] = [
    ("SPC", "play / stop"),
    ("G", "god capture"),
    ("A", "select pad left"),
    ("D", "select pad right"),
    ("W", "mute / unmute active pad"),
    ("M", "metronome"),
    ("↑", "bpm +1"),
    ("↓", "bpm -1"),
    ("[", "fewer bars"),
    ("]", "more bars"),
    ("-", "volume down"),
    ("+", "volume up"),
    ("Z", "undo clear"),
    ("C", "clear active pad"),
    ("T", "setup pads"),
    ("ESC", "stop"),
    ("?", "this help"),
]
```

- [ ] **Step 2: Run build**

Run: `cd ~/god/GOD && swift build 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add GOD/GOD/Views/KeyReferenceOverlay.swift
git commit -m "feat: update KeyReferenceOverlay with new WASD shortcuts"
```

---

### Task 9: Remove remaining old view files

**Files:**
- Remove: `GOD/GOD/Views/ChannelRowView.swift`
- Remove: `GOD/GOD/Views/GenesisTerminalView.swift`
- Remove: `GOD/GOD/Views/SignalMeterView.swift`
- Remove: `GOD/GOD/Views/LoopBarView.swift`
- Remove: `GOD/GOD/Views/CaptureIndicatorView.swift`
- Remove: `GOD/GOD/Views/TipView.swift`

(LLMManager, StateSnapshot, Tips, and their tests were already removed in Task 2.)

- [ ] **Step 1: Delete remaining old view files**

```bash
cd ~/god
rm GOD/GOD/Views/ChannelRowView.swift \
   GOD/GOD/Views/GenesisTerminalView.swift \
   GOD/GOD/Views/SignalMeterView.swift \
   GOD/GOD/Views/LoopBarView.swift \
   GOD/GOD/Views/CaptureIndicatorView.swift \
   GOD/GOD/Views/TipView.swift
```

- [ ] **Step 2: Run full test suite**

Run: `cd ~/god/GOD && swift test 2>&1 | tail -30`
Expected: All tests pass

- [ ] **Step 3: Run the app**

Run: `cd ~/god/GOD && swift build && .build/arm64-apple-macosx/debug/GOD`
Expected: App launches with new layout — transport bar, canvas with ASCII GOD title, pad strip, hotkeys.

- [ ] **Step 4: Commit**

```bash
git add -u
git commit -m "refactor: remove old views, complete UI redesign wiring"
```

---

### Task 10: Smoke test and final polish

- [ ] **Step 1: Run full test suite one more time**

Run: `cd ~/god/GOD && swift test 2>&1 | tail -30`
Expected: All tests pass

- [ ] **Step 2: Verify keyboard shortcuts**

Launch the app. Verify:
- `SPC` toggles play (GOD title lights up blue)
- `A/D` moves active pad selection left/right
- `W` mutes/unmutes active pad
- `C` clears active pad
- `T` opens setup modal
- `↑/↓` adjusts BPM
- `[/]` changes bar count
- `-/+` adjusts volume
- `G` arms/toggles capture
- `M` toggles metronome
- `Z` undoes last clear
- `?` shows help overlay
- `ESC` stops playback

- [ ] **Step 3: Verify terminal output**

Play a beat, trigger pads via MIDI or loaded samples. Check:
- Terminal shows hit events (`kick .1s — vel 112`)
- CC knob changes appear in terminal
- Loop boundary summaries appear
- Mute/unmute events appear

- [ ] **Step 4: Verify visuals**

- Visual columns rise from pads on hit
- Columns decay after hit
- Muted pads show no visual activity
- Active pad shows CC values

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore: UI redesign complete — canvas, pads, engine terminal"
```

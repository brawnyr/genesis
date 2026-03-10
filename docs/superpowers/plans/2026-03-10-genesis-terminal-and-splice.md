# Genesis Terminal & Splice Integration — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Splice sample auto-loading, split the UI into instrument + terminal panels, and integrate a local llama model for real-time session commentary.

**Architecture:** Three independent subsystems — (1) Splice folder scanning in PadBank, (2) split-view UI with a new GenesisTerminalView, (3) LLM subprocess manager that observes engine state and feeds text to the terminal. The LLM system runs entirely off the audio thread with debounced event-driven updates.

**Tech Stack:** Swift, SwiftUI, AVFoundation, Foundation (Process/Pipe for llama.cpp subprocess), Swift Testing

**Spec:** `docs/superpowers/specs/2026-03-10-genesis-terminal-and-splice-design.md`

---

## File Map

### New Files
| File | Responsibility |
|------|---------------|
| `GOD/GOD/Engine/LLMManager.swift` | Subprocess lifecycle, inference requests, debounce, response parsing |
| `GOD/GOD/Engine/StateSnapshot.swift` | Codable struct + builder that captures engine state as JSON for LLM |
| `GOD/GOD/Views/GenesisTerminalView.swift` | Right-panel terminal: scrolling text with opacity fade |
| `GOD/Tests/SpliceLoadingTests.swift` | Splice folder scanning + priority tests |
| `GOD/Tests/StateSnapshotTests.swift` | Snapshot JSON generation + truncation detection |
| `GOD/Tests/LLMManagerTests.swift` | Debounce logic, lifecycle states |

### Modified Files
| File | Changes |
|------|---------|
| `GOD/GOD/Models/Sample.swift` | Add `durationMs` computed property |
| `GOD/GOD/Models/Pad.swift` | Add `loadFromSpliceFolders()` method to PadBank |
| `GOD/GOD/Engine/GodEngine.swift` | Add `stateSnapshot()` method, expose `loopDurationMs`, wire LLMManager |
| `GOD/GOD/ContentView.swift` | Split into HStack (instrument left, terminal right), add `T` key toggle |
| `GOD/GOD/GODApp.swift` | Update default window size, call Splice loading on startup, start LLMManager |
| `GOD/GOD/Views/Theme.swift` | Add `terminalText` and `terminalDim` colors |
| `GOD/GOD/Views/KeyReferenceOverlay.swift` | Add `T` shortcut to help overlay |

---

## Chunk 1: Splice Sample Loading

### Task 1: Add `durationMs` to Sample

**Files:**
- Modify: `GOD/GOD/Models/Sample.swift`
- Test: `GOD/Tests/SpliceLoadingTests.swift`

- [ ] **Step 1: Write the failing test**

Create `GOD/Tests/SpliceLoadingTests.swift`:

```swift
import Testing
@testable import GOD

@Test func sampleDurationMs() {
    // 44100 frames at 44100Hz = 1000ms
    let sample = Sample(name: "test", left: [Float](repeating: 0, count: 44100),
                        right: [Float](repeating: 0, count: 44100), sampleRate: 44100)
    #expect(sample.durationMs == 1000.0)
}

@Test func sampleDurationMsShort() {
    // 22050 frames at 44100Hz = 500ms
    let sample = Sample(name: "short", left: [Float](repeating: 0, count: 22050),
                        right: [Float](repeating: 0, count: 22050), sampleRate: 44100)
    #expect(sample.durationMs == 500.0)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/god/GOD && swift test --filter sampleDurationMs 2>&1 | tail -5`
Expected: FAIL — `durationMs` does not exist on Sample

- [ ] **Step 3: Write minimal implementation**

In `GOD/GOD/Models/Sample.swift`, add after `var frameCount`:

```swift
var durationMs: Double {
    Double(frameCount) / sampleRate * 1000.0
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/god/GOD && swift test --filter sampleDuration 2>&1 | tail -5`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd ~/god && git add GOD/GOD/Models/Sample.swift GOD/Tests/SpliceLoadingTests.swift
git commit -m "feat: add durationMs computed property to Sample"
```

---

### Task 2: Add Splice folder scanning to PadBank

**Files:**
- Modify: `GOD/GOD/Models/Pad.swift`
- Test: `GOD/Tests/SpliceLoadingTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `GOD/Tests/SpliceLoadingTests.swift`:

```swift
@Test func spliceFolderNames() {
    #expect(PadBank.spliceFolderNames == ["kicks", "snares", "hats", "perc", "bass", "keys", "vox", "fx"])
}

@Test func spliceFolderPath() {
    let base = PadBank.spliceBasePath
    #expect(base.path.hasSuffix("Splice/sounds"))
}

@Test func loadFromSpliceSkipsLoadedPads() {
    var bank = PadBank()
    let sample = Sample(name: "manual", left: [0.1], right: [0.1], sampleRate: 44100)
    bank.assign(sample: sample, toPad: 0)
    bank.pads[0].samplePath = "/manual/kick.wav"

    // After loading splice, pad 0 should still have the manual sample
    bank.loadFromSpliceFolders()
    #expect(bank.pads[0].sample?.name == "manual")
    #expect(bank.pads[0].samplePath == "/manual/kick.wav")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/god/GOD && swift test --filter splice 2>&1 | tail -10`
Expected: FAIL — `spliceFolderNames`, `spliceBasePath`, `loadFromSpliceFolders` don't exist

- [ ] **Step 3: Write minimal implementation**

In `GOD/GOD/Models/Pad.swift`, add to `PadBank`:

```swift
static let spliceFolderNames = ["kicks", "snares", "hats", "perc", "bass", "keys", "vox", "fx"]

static let spliceBasePath: URL = {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Splice")
        .appendingPathComponent("sounds")
}()

private static let audioExtensions: Set<String> = ["wav", "aif", "aiff", "mp3", "m4a", "flac", "ogg"]

mutating func loadFromSpliceFolders() {
    let fm = FileManager.default
    for (index, folderName) in Self.spliceFolderNames.enumerated() {
        // Skip pads that already have a sample loaded (pads.json took priority)
        guard pads[index].sample == nil else { continue }

        let folderURL = Self.spliceBasePath.appendingPathComponent(folderName)
        guard let contents = try? fm.contentsOfDirectory(at: folderURL,
                                                          includingPropertiesForKeys: nil)
                .filter({ Self.audioExtensions.contains($0.pathExtension.lowercased()) })
                .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        else { continue }

        guard let firstFile = contents.first,
              let sample = try? Sample.load(from: firstFile) else { continue }

        pads[index].sample = sample
        pads[index].samplePath = firstFile.path
        pads[index].name = sample.name.uppercased()
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/god/GOD && swift test --filter splice 2>&1 | tail -10`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd ~/god && git add GOD/GOD/Models/Pad.swift GOD/Tests/SpliceLoadingTests.swift
git commit -m "feat: add Splice folder scanning to PadBank"
```

---

### Task 3: Wire Splice loading into app startup

**Files:**
- Modify: `GOD/GOD/GODApp.swift`

- [ ] **Step 1: Add Splice loading to startManagers**

In `GODApp.swift`, update `startManagers()` to load config then scan Splice:

```swift
private func startManagers() {
    // Load saved pad config, then fill gaps from Splice folders
    try? engine.padBank.loadConfig()
    engine.padBank.loadFromSpliceFolders()
    try? engine.padBank.save()

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
```

- [ ] **Step 2: Create the Splice folders if they don't exist**

Add a helper call before loading:

```swift
private func ensureSpliceFolders() {
    let fm = FileManager.default
    for name in PadBank.spliceFolderNames {
        let url = PadBank.spliceBasePath.appendingPathComponent(name)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
```

Call `ensureSpliceFolders()` at the start of `startManagers()`.

- [ ] **Step 3: Build and verify**

Run: `cd ~/god/GOD && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
cd ~/god && git add GOD/GOD/GODApp.swift
git commit -m "feat: wire Splice folder loading into app startup"
```

---

## Chunk 2: Split View UI

### Task 4: Add terminal theme colors

**Files:**
- Modify: `GOD/GOD/Views/Theme.swift`

- [ ] **Step 1: Add colors**

In `Theme.swift`, add:

```swift
// Terminal text — same white but for dimming
static let terminalText = Color.white
static let terminalDim = Color(white: 0.4)
```

- [ ] **Step 2: Build to verify**

Run: `cd ~/god/GOD && swift build 2>&1 | tail -3`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
cd ~/god && git add GOD/GOD/Views/Theme.swift
git commit -m "feat: add terminal theme colors"
```

---

### Task 5: Create GenesisTerminalView

**Files:**
- Create: `GOD/GOD/Views/GenesisTerminalView.swift`

- [ ] **Step 1: Create the view**

Create `GOD/GOD/Views/GenesisTerminalView.swift`:

```swift
import SwiftUI

struct TerminalLine: Identifiable {
    let id = UUID()
    let text: String
    let isHighlight: Bool
}

class TerminalState: ObservableObject {
    @Published var lines: [TerminalLine] = []
    private let maxLines = 50

    func append(_ text: String, highlight: Bool = false) {
        let line = TerminalLine(text: text, isHighlight: highlight)
        lines.append(line)
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
    }

    func setStatus(_ text: String) {
        lines = [TerminalLine(text: text, isHighlight: false)]
    }
}

struct GenesisTerminalView: View {
    @ObservedObject var state: TerminalState

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(state.lines.enumerated()), id: \.element.id) { index, line in
                        Text(line.text)
                            .font(Theme.monoSmall)
                            .foregroundColor(line.isHighlight ? Theme.blue : Theme.terminalText)
                            .opacity(lineOpacity(index: index, total: state.lines.count))
                            .id(line.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
            .onChange(of: state.lines.count) { _, _ in
                if let last = state.lines.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(Theme.bg)
    }

    private func lineOpacity(index: Int, total: Int) -> Double {
        guard total > 1 else { return 1.0 }
        let position = Double(index) / Double(total - 1)
        // Linear: 0.3 for oldest, 1.0 for newest
        return 0.3 + 0.7 * position
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `cd ~/god/GOD && swift build 2>&1 | tail -3`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
cd ~/god && git add GOD/GOD/Views/GenesisTerminalView.swift
git commit -m "feat: add GenesisTerminalView with scrolling opacity fade"
```

---

### Task 6: Split ContentView into HStack layout

**Files:**
- Modify: `GOD/GOD/ContentView.swift`
- Modify: `GOD/GOD/GODApp.swift`

- [ ] **Step 1: Add terminal state and toggle to ContentView**

Add a `@State private var showTerminal = true` and `@ObservedObject var terminalState: TerminalState` to ContentView.

Update `body` to wrap the instrument VStack and terminal in an HStack:

```swift
struct ContentView: View {
    @ObservedObject var engine: GodEngine
    @ObservedObject var terminalState: TerminalState
    @State private var showSetup = false
    @State private var showKeyReference = false
    @State private var showTerminal = true

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            KeyCaptureRepresentable { keyCode, chars in
                handleKey(keyCode: keyCode, chars: chars)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // Left: Instrument panel
                    VStack(spacing: 20) {
                        TransportView(engine: engine)
                            .padding(.top, 16)

                        LoopBarView(engine: engine)

                        ChannelListView(engine: engine)
                            .padding(.vertical, 8)

                        Spacer()

                        CaptureIndicatorView(engine: engine)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)

                    if showTerminal {
                        // Right: Genesis Terminal
                        GenesisTerminalView(state: terminalState)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Bottom: Tips + key strip (full width)
                VStack(spacing: 4) {
                    TipView()
                        .padding(.vertical, 4)

                    HStack(spacing: 14) {
                        KeyLabel(key: "SPC", action: "play")
                        KeyLabel(key: "G", action: "god")
                        KeyLabel(key: "M", action: "metro")
                        KeyLabel(key: "S", action: "setup")
                        KeyLabel(key: "↑↓", action: "bpm")
                        KeyLabel(key: "[]", action: "bars")
                        KeyLabel(key: "-+", action: "vol")
                        KeyLabel(key: "1-8", action: "mute")
                        KeyLabel(key: "Z", action: "undo")
                        KeyLabel(key: "T", action: "term")
                        KeyLabel(key: "?", action: "help")
                    }
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, 24)
            }

            if showKeyReference {
                KeyReferenceOverlay(isVisible: $showKeyReference)
            }
        }
        .sheet(isPresented: $showSetup) {
            SetupView(engine: engine, isPresented: $showSetup)
                .frame(width: 500, height: 500)
        }
    }
```

- [ ] **Step 2: Add `T` key handler**

In the `handleKey` method, add a case for `T` (keyCode 17):

```swift
// Add to the Key enum:
static let t: UInt16 = 17

// Add to the switch in handleKey:
case Key.t:
    showTerminal.toggle()
```

- [ ] **Step 3: Update GODApp window size and pass terminal state**

In `GODApp.swift`:

```swift
@StateObject private var terminalState = TerminalState()
```

Update the ContentView call:
```swift
ContentView(engine: engine, terminalState: terminalState)
```

Update default window size and add minimum:
```swift
.defaultSize(width: 1000, height: 700)
```

Add a frame constraint in ContentView's outermost ZStack:
```swift
.frame(minWidth: 800, minHeight: 500)
```

- [ ] **Step 4: Update KeyReferenceOverlay**

Add `T` shortcut to `GOD/GOD/Views/KeyReferenceOverlay.swift`.

- [ ] **Step 5: Build to verify**

Run: `cd ~/god/GOD && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 6: Commit**

```bash
cd ~/god && git add GOD/GOD/ContentView.swift GOD/GOD/GODApp.swift GOD/GOD/Views/KeyReferenceOverlay.swift
git commit -m "feat: split UI into instrument + Genesis Terminal panels"
```

---

## Chunk 3: LLM Integration

### Task 7: Create StateSnapshot

**Files:**
- Create: `GOD/GOD/Engine/StateSnapshot.swift`
- Create: `GOD/Tests/StateSnapshotTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `GOD/Tests/StateSnapshotTests.swift`:

```swift
import Testing
import Foundation
@testable import GOD

@Test func snapshotChannelTruncation() {
    // Sample is 10000ms, loop is 8000ms — should be truncated
    let channel = StateSnapshot.Channel(
        ch: 1, sample: "pad.wav",
        sampleDurationMs: 10000, loopDurationMs: 8000,
        hits: 1, muted: false,
        volume: 1.0, pan: 0.5,
        hpHz: 20, lpHz: 20000,
        peakDb: -12.0
    )
    #expect(channel.truncated == true)
}

@Test func snapshotChannelNotTruncated() {
    let channel = StateSnapshot.Channel(
        ch: 1, sample: "kick.wav",
        sampleDurationMs: 450, loopDurationMs: 8000,
        hits: 4, muted: false,
        volume: 0.8, pan: 0.5,
        hpHz: 20, lpHz: 20000,
        peakDb: -6.0
    )
    #expect(channel.truncated == false)
}

@Test func snapshotEncodesToJSON() throws {
    let snapshot = StateSnapshot(
        bpm: 120, bars: 4, beat: 1,
        playing: true, capture: "idle",
        channels: [
            StateSnapshot.Channel(
                ch: 1, sample: "kick.wav",
                sampleDurationMs: 450, loopDurationMs: 8000,
                hits: 4, muted: false,
                volume: 0.8, pan: 0.5,
                hpHz: 20, lpHz: 20000,
                peakDb: -12.0
            )
        ]
    )
    let data = try JSONEncoder().encode(snapshot)
    let json = String(data: data, encoding: .utf8)!
    #expect(json.contains("\"bpm\":120"))
    #expect(json.contains("\"truncated\":false"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/god/GOD && swift test --filter snapshot 2>&1 | tail -5`
Expected: FAIL — `StateSnapshot` does not exist

- [ ] **Step 3: Write implementation**

Create `GOD/GOD/Engine/StateSnapshot.swift`:

```swift
import Foundation

struct StateSnapshot: Codable {
    let bpm: Int
    let bars: Int
    let beat: Int
    let playing: Bool
    let capture: String
    let channels: [Channel]

    struct Channel: Codable {
        let ch: Int
        let sample: String
        let sampleDurationMs: Double
        let loopDurationMs: Double
        let hits: Int
        let muted: Bool
        let volume: Float
        let pan: Float
        let hpHz: Float
        let lpHz: Float
        let peakDb: Float
        var truncated: Bool { sampleDurationMs > loopDurationMs }

        enum CodingKeys: String, CodingKey {
            case ch, sample
            case sampleDurationMs = "sample_duration_ms"
            case loopDurationMs = "loop_duration_ms"
            case hits, muted, volume, pan
            case hpHz = "hp_hz"
            case lpHz = "lp_hz"
            case peakDb = "peak_db"
            case truncated
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(ch, forKey: .ch)
            try container.encode(sample, forKey: .sample)
            try container.encode(sampleDurationMs, forKey: .sampleDurationMs)
            try container.encode(loopDurationMs, forKey: .loopDurationMs)
            try container.encode(hits, forKey: .hits)
            try container.encode(muted, forKey: .muted)
            try container.encode(volume, forKey: .volume)
            try container.encode(pan, forKey: .pan)
            try container.encode(hpHz, forKey: .hpHz)
            try container.encode(lpHz, forKey: .lpHz)
            try container.encode(peakDb, forKey: .peakDb)
            try container.encode(truncated, forKey: .truncated)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/god/GOD && swift test --filter snapshot 2>&1 | tail -5`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd ~/god && git add GOD/GOD/Engine/StateSnapshot.swift GOD/Tests/StateSnapshotTests.swift
git commit -m "feat: add StateSnapshot for LLM engine state serialization"
```

---

### Task 8: Add `stateSnapshot()` to GodEngine

**Files:**
- Modify: `GOD/GOD/Engine/GodEngine.swift`
- Modify: `GOD/Tests/StateSnapshotTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `GOD/Tests/StateSnapshotTests.swift`:

```swift
@Test func engineProducesSnapshot() {
    let engine = GodEngine()
    let snapshot = engine.stateSnapshot(peakLevels: Array(repeating: Float(-20.0), count: 8))
    #expect(snapshot.bpm == 120)
    #expect(snapshot.bars == 4)
    #expect(snapshot.playing == false)
    #expect(snapshot.channels.count == 8)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/god/GOD && swift test --filter engineProducesSnapshot 2>&1 | tail -5`
Expected: FAIL — `stateSnapshot` does not exist on GodEngine

- [ ] **Step 3: Write implementation**

Add to `GodEngine.swift`:

```swift
var loopDurationMs: Double {
    Double(transport.loopLengthFrames) / Transport.sampleRate * 1000.0
}

func stateSnapshot(peakLevels: [Float]) -> StateSnapshot {
    let loopMs = loopDurationMs
    let beatLenFrames = transport.loopLengthFrames / (transport.barCount * 4)
    let currentBeat = beatLenFrames > 0 ? (transport.position / beatLenFrames) + 1 : 1

    let captureStr: String
    switch capture.state {
    case .idle: captureStr = "idle"
    case .armed: captureStr = "armed"
    case .recording: captureStr = "recording"
    }

    let channels = (0..<8).map { i -> StateSnapshot.Channel in
        let pad = padBank.pads[i]
        let layer = layers[i]
        let sampleMs = pad.sample?.durationMs ?? 0
        let peak = i < peakLevels.count ? peakLevels[i] : -100
        let peakDb = peak > 0 ? 20.0 * log10(peak) : -100.0

        return StateSnapshot.Channel(
            ch: i + 1,
            sample: pad.sample?.name ?? "—",
            sampleDurationMs: sampleMs,
            loopDurationMs: loopMs,
            hits: layer.hits.count,
            muted: layer.isMuted,
            volume: layer.volume,
            pan: layer.pan,
            hpHz: layer.hpCutoff,
            lpHz: layer.lpCutoff,
            peakDb: Float(peakDb)
        )
    }

    return StateSnapshot(
        bpm: transport.bpm,
        bars: transport.barCount,
        beat: currentBeat,
        playing: transport.isPlaying,
        capture: captureStr,
        channels: channels
    )
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/god/GOD && swift test --filter engineProducesSnapshot 2>&1 | tail -5`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd ~/god && git add GOD/GOD/Engine/GodEngine.swift GOD/Tests/StateSnapshotTests.swift
git commit -m "feat: add stateSnapshot() to GodEngine for LLM feed"
```

---

### Task 9: Create LLMManager

**Files:**
- Create: `GOD/GOD/Engine/LLMManager.swift`
- Create: `GOD/Tests/LLMManagerTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `GOD/Tests/LLMManagerTests.swift`:

```swift
import Testing
import Foundation
@testable import GOD

@Test func llmManagerDebounce() async throws {
    let manager = LLMManager(terminalState: TerminalState())

    // Request twice rapidly — second should be debounced
    let snapshot = StateSnapshot(
        bpm: 120, bars: 4, beat: 1,
        playing: true, capture: "idle", channels: []
    )
    manager.requestInference(snapshot: snapshot)
    manager.requestInference(snapshot: snapshot)

    #expect(manager.pendingRequestCount <= 1)
}

@Test func llmManagerModelMissing() {
    let state = TerminalState()
    let manager = LLMManager(terminalState: state)
    manager.start()

    // Should show missing model message
    #expect(state.lines.first?.text.contains("no model loaded") == true)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/god/GOD && swift test --filter llmManager 2>&1 | tail -5`
Expected: FAIL — `LLMManager` does not exist

- [ ] **Step 3: Write implementation**

Create `GOD/GOD/Engine/LLMManager.swift`:

```swift
import Foundation
import os

private let logger = Logger(subsystem: "com.god.llm", category: "LLMManager")

class LLMManager {
    private let terminalState: TerminalState
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private let queue = DispatchQueue(label: "com.god.llm", qos: .utility)
    private var lastRequestTime: Date = .distantPast
    private var _pendingRequestCount = 0
    private let debounceInterval: TimeInterval = 2.0
    private let timeoutInterval: TimeInterval = 3.0
    private var isRunning = false
    private var lastSnapshotJSON: String?

    var pendingRequestCount: Int {
        queue.sync { _pendingRequestCount }
    }

    static let modelsDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".god")
            .appendingPathComponent("models")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static let systemPrompt = """
    You are a studio session observer for GOD, a loop-stacking instrument. \
    You receive JSON snapshots of the engine state. Respond with 1-2 short lines \
    of commentary about what's happening musically. Be warm, conversational, \
    and accurate. Note truncated samples, frequency overlaps, filter settings, \
    and rhythmic patterns. Don't be stiff — talk like a studio partner in the room.
    """

    init(terminalState: TerminalState) {
        self.terminalState = terminalState
    }

    func start() {
        // Find model file
        let fm = FileManager.default
        guard let modelFile = findModelFile() else {
            DispatchQueue.main.async {
                self.terminalState.setStatus("no model loaded — drop a gguf into ~/.god/models/")
            }
            return
        }

        // Find llama-cli binary
        guard let llamaBinary = findLlamaBinary() else {
            DispatchQueue.main.async {
                self.terminalState.setStatus("llama-cli not found — install llama.cpp")
            }
            return
        }

        queue.async { [weak self] in
            self?.launchProcess(binary: llamaBinary, model: modelFile)
        }
    }

    func stop() {
        isRunning = false
        process?.terminate()
        process = nil
    }

    func requestInference(snapshot: StateSnapshot) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let now = Date()
            guard now.timeIntervalSince(self.lastRequestTime) >= self.debounceInterval else { return }
            guard self._pendingRequestCount == 0 else { return }
            guard self.isRunning else { return }

            // Skip if state hasn't changed since last request
            if let json = try? JSONEncoder().encode(snapshot),
               let jsonStr = String(data: json, encoding: .utf8),
               jsonStr == self.lastSnapshotJSON { return }

            self.lastRequestTime = now
            self._pendingRequestCount += 1
            self.sendRequest(snapshot: snapshot)
        }
    }

    private func findModelFile() -> URL? {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: Self.modelsDir,
                                                          includingPropertiesForKeys: nil) else { return nil }
        return contents.first { $0.pathExtension == "gguf" }
    }

    private func findLlamaBinary() -> String? {
        let candidates = [
            "/usr/local/bin/llama-cli",
            "/opt/homebrew/bin/llama-cli",
        ]
        let fm = FileManager.default
        return candidates.first { fm.fileExists(atPath: $0) }
    }

    private func launchProcess(binary: String, model: URL) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binary)
        proc.arguments = [
            "-m", model.path,
            "--interactive",
            "-c", "2048",
            "--temp", "0.7",
            "-p", Self.systemPrompt
        ]

        let stdin = Pipe()
        let stdout = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            self.process = proc
            self.stdinPipe = stdin
            self.stdoutPipe = stdout
            self.isRunning = true

            // Detect crashes
            proc.terminationHandler = { [weak self] _ in
                self?.isRunning = false
                self?._pendingRequestCount = 0
                DispatchQueue.main.async {
                    self?.terminalState.append("model disconnected")
                }
            }

            DispatchQueue.main.async {
                self.terminalState.append("genesis terminal online", highlight: true)
            }

            // Read output on background thread
            readOutput(from: stdout)
        } catch {
            logger.error("Failed to launch llama: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.terminalState.setStatus("model disconnected")
            }
        }
    }

    private func readOutput(from pipe: Pipe) {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            self?.queue.async { self?._pendingRequestCount = 0 }

            DispatchQueue.main.async {
                // Split multi-line responses
                for line in trimmed.components(separatedBy: .newlines) {
                    let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleaned.isEmpty else { continue }
                    self?.terminalState.append(cleaned)
                }
            }
        }
    }

    private func sendRequest(snapshot: StateSnapshot) {
        guard let pipe = stdinPipe else {
            _pendingRequestCount = 0
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let json = try encoder.encode(snapshot)
            guard var text = String(data: json, encoding: .utf8) else { return }
            lastSnapshotJSON = text
            text += "\n"

            pipe.fileHandleForWriting.write(text.data(using: .utf8)!)

            // Timeout: if no response in 3s, drop
            queue.asyncAfter(deadline: .now() + timeoutInterval) { [weak self] in
                if self?._pendingRequestCount ?? 0 > 0 {
                    self?._pendingRequestCount = 0
                }
            }
        } catch {
            _pendingRequestCount = 0
        }
    }

    deinit {
        stop()
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/god/GOD && swift test --filter llmManager 2>&1 | tail -10`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd ~/god && git add GOD/GOD/Engine/LLMManager.swift GOD/Tests/LLMManagerTests.swift
git commit -m "feat: add LLMManager for llama.cpp subprocess integration"
```

---

### Task 10: Wire LLMManager into GodEngine and app lifecycle

**Files:**
- Modify: `GOD/GOD/GODApp.swift`
- Modify: `GOD/GOD/Engine/GodEngine.swift`

- [ ] **Step 1: Add LLMManager to GODApp**

In `GODApp.swift`, add:

```swift
@StateObject private var llmManager: LLMManager
```

Since `LLMManager` needs `terminalState`, initialize them together. Update `init()`:

```swift
@StateObject private var terminalState = TerminalState()
@State private var llmManager: LLMManager?
```

In `startManagers()`, after audio/MIDI setup:

```swift
let llm = LLMManager(terminalState: terminalState)
llm.start()
llmManager = llm
```

- [ ] **Step 2: Add event-driven inference trigger to GodEngine**

Add a callback property to `GodEngine`:

```swift
var onStateChanged: (() -> Void)?
```

Fire it at the end of the UI update block in `processBlock`, inside the `DispatchQueue.main.async` closure at line 283 of `GodEngine.swift`. Insert after the `for i in 0..<8` loop (after line 303), still inside the `DispatchQueue.main.async` block:

```swift
self.onStateChanged?()
```

- [ ] **Step 3: Connect the callback in GODApp.startManagers**

After creating `llmManager`:

```swift
engine.onStateChanged = { [weak engine, weak llm] in
    guard let engine = engine, let llm = llm else { return }
    let snapshot = engine.stateSnapshot(peakLevels: engine.channelSignalLevels)
    llm.requestInference(snapshot: snapshot)
}
```

The debounce inside `LLMManager` handles the throttling — this callback fires ~30Hz but only triggers real inference every 2s.

- [ ] **Step 4: Build to verify**

Run: `cd ~/god/GOD && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
cd ~/god && git add GOD/GOD/GODApp.swift GOD/GOD/Engine/GodEngine.swift
git commit -m "feat: wire LLMManager into app lifecycle with event-driven inference"
```

---

### Task 11: Run all tests and verify

- [ ] **Step 1: Run full test suite**

Run: `cd ~/god/GOD && swift test 2>&1 | tail -20`
Expected: All tests pass (existing 11 test files + 3 new ones)

- [ ] **Step 2: Build and launch to verify**

Run: `cd ~/god/GOD && swift build 2>&1 | tail -5`
Expected: Build succeeds. App launches with split view. Terminal shows model status.

- [ ] **Step 3: Final commit if any fixes needed**

Stage only the specific files that were fixed, then commit:
```bash
cd ~/god && git add <fixed-files> && git commit -m "fix: address test/build issues"
```

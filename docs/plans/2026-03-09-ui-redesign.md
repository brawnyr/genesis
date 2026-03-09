# GOD UI Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rebuild GOD's view layer into a bold, keyboard-only interface with Claude-inspired blues/oranges/whites, live signal meters, trigger flashes, and breathing animations.

**Architecture:** Engine layer stays untouched except adding per-channel signal level tracking. All view files get rewritten or replaced. New `ChannelRowView`, `SignalMeterView`, and `KeyReferenceOverlay` components. Command input hidden by default, revealed with `/`.

**Tech Stack:** Swift, SwiftUI, macOS 14+

---

### Task 1: Update Theme — new color palette

**Files:**
- Modify: `GOD/GOD/Views/Theme.swift`

**Step 1: Rewrite Theme.swift with new palette**

Replace the entire contents of `GOD/GOD/Views/Theme.swift`:

```swift
import SwiftUI

enum Theme {
    // Background
    static let bg = Color(red: 0.102, green: 0.098, blue: 0.090)       // #1a1917

    // Text — bright white, always pops
    static let text = Color.white

    // Claude blue — active state, playing, channels
    static let blue = Color(red: 0.384, green: 0.514, blue: 0.886)     // #6283e2

    // Orange — hot state, recording, triggers
    static let orange = Color(red: 0.855, green: 0.482, blue: 0.290)   // #da7b4a

    // Status colors
    static let green = Color(red: 0.373, green: 0.667, blue: 0.431)    // #5faa6e
    static let red = Color(red: 0.831, green: 0.337, blue: 0.306)      // #d4564e
    static let amber = Color(red: 0.831, green: 0.635, blue: 0.306)    // #d4a24e

    // Subtle — only for empty slots and track background
    static let subtle = Color(white: 0.25)

    // Fonts
    static let mono = Font.system(size: 13, design: .monospaced)
    static let monoSmall = Font.system(size: 11, design: .monospaced)
    static let monoTiny = Font.system(size: 10, design: .monospaced)
    static let monoLarge = Font.system(size: 18, design: .monospaced)
    static let monoTitle = Font.system(size: 24, design: .monospaced).weight(.bold)
}
```

**Step 2: Build to verify no compile errors**

Run: `cd /Users/brawny/god/GOD && swift build 2>&1`
Expected: Build succeeds (views will have errors referencing old colors — that's fine, we fix them next)

**Step 3: Commit**

```bash
git add GOD/GOD/Views/Theme.swift
git commit -m "feat: update theme with Claude blue/orange/white palette"
```

---

### Task 2: Add signal level tracking to GodEngine

**Files:**
- Modify: `GOD/GOD/Engine/GodEngine.swift`
- Test: `GOD/Tests/GodEngineTests.swift`

**Step 1: Write the failing test**

Add to `GOD/Tests/GodEngineTests.swift`:

```swift
@Test func signalLevelsUpdateDuringPlayback() async {
    let engine = await GodEngine()
    await MainActor.run {
        // Signal levels should start at zero
        for level in engine.channelSignalLevels {
            #expect(level == 0.0)
        }
        #expect(engine.channelSignalLevels.count == 8)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/brawny/god/GOD && swift test --filter signalLevelsUpdateDuringPlayback 2>&1`
Expected: FAIL — `channelSignalLevels` does not exist

**Step 3: Add signal level tracking to GodEngine**

Add this published property after the `capture` declaration (line 9):

```swift
@Published var channelSignalLevels: [Float] = Array(repeating: 0, count: 8)
@Published var channelTriggered: [Bool] = Array(repeating: false, count: 8)
```

In `processBlock(frameCount:)`, after the voice mixing section (after line 110 `voices = voices.compactMap { ... }`), add signal level calculation:

```swift
// Calculate per-channel signal levels (peak detection)
var newLevels = Array<Float>(repeating: 0, count: 8)
for voice in voices {
    // Find which channel this voice belongs to by matching sample
    for i in 0..<8 {
        if let padSample = padBank.pads[i].sample,
           padSample.name == voice.sample.name {
            // Peak from current position
            let remaining = min(frameCount, voice.sample.data.count - voice.position)
            if remaining > 0 {
                let start = max(0, voice.position)
                let end = min(voice.sample.data.count, start + remaining)
                for j in start..<end {
                    newLevels[i] = max(newLevels[i], abs(voice.sample.data[j] * voice.velocity))
                }
            }
        }
    }
}

DispatchQueue.main.async { [newLevels] in
    self.channelSignalLevels = newLevels
}
```

Also in `onPadHit(note:velocity:)`, after `voices.append(...)`, add:

```swift
DispatchQueue.main.async {
    self.channelTriggered[padIndex] = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.channelTriggered[padIndex] = false
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/brawny/god/GOD && swift test --filter signalLevelsUpdateDuringPlayback 2>&1`
Expected: PASS

**Step 5: Commit**

```bash
git add GOD/GOD/Engine/GodEngine.swift GOD/Tests/GodEngineTests.swift
git commit -m "feat: add per-channel signal level tracking and trigger flash state"
```

---

### Task 3: Rewrite TitleView — breathing white title

**Files:**
- Modify: `GOD/GOD/Views/TitleView.swift`

**Step 1: Rewrite TitleView.swift**

```swift
import SwiftUI

struct TitleView: View {
    @State private var breathing = false

    var body: some View {
        Text("G   O   D")
            .font(Theme.monoTitle)
            .foregroundColor(Theme.text)
            .opacity(breathing ? 1.0 : 0.7)
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            }
    }
}
```

**Step 2: Build**

Run: `cd /Users/brawny/god/GOD && swift build 2>&1`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add GOD/GOD/Views/TitleView.swift
git commit -m "feat: breathing white title"
```

---

### Task 4: Rewrite TransportView — bold white with beat counter

**Files:**
- Modify: `GOD/GOD/Views/TransportView.swift`

**Step 1: Rewrite TransportView.swift**

```swift
import SwiftUI

struct TransportView: View {
    @ObservedObject var engine: GodEngine
    @State private var beatPulse = false

    private var currentBeat: Int {
        let beatLength = engine.metronome.beatLengthFrames(
            bpm: engine.transport.bpm,
            sampleRate: Transport.sampleRate
        )
        guard beatLength > 0 else { return 1 }
        return (engine.transport.position / beatLength) % (engine.transport.barCount * 4) + 1
    }

    var body: some View {
        HStack(spacing: 20) {
            // Play state
            Text(engine.transport.isPlaying ? "▶" : "■")
                .foregroundColor(engine.transport.isPlaying ? Theme.blue : Theme.text)
                .font(Theme.monoLarge)

            // BPM
            Text("\(engine.transport.bpm) bpm")
                .foregroundColor(Theme.text)

            // Bars
            Text("\(engine.transport.barCount) bars")
                .foregroundColor(Theme.text)

            // Metronome
            Text("♩ \(engine.metronome.isOn ? "on" : "off")")
                .foregroundColor(engine.metronome.isOn ? Theme.blue : Theme.text)

            Spacer()

            // Beat counter
            if engine.transport.isPlaying {
                Text("beat \(currentBeat)")
                    .foregroundColor(Theme.blue)
            }
        }
        .font(Theme.mono)
    }
}
```

**Step 2: Build**

Run: `cd /Users/brawny/god/GOD && swift build 2>&1`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add GOD/GOD/Views/TransportView.swift
git commit -m "feat: bold white transport with beat counter"
```

---

### Task 5: Rewrite LoopBarView — smooth blue fill

**Files:**
- Modify: `GOD/GOD/Views/LoopBarView.swift`

**Step 1: Rewrite LoopBarView.swift**

```swift
import SwiftUI

struct LoopBarView: View {
    @ObservedObject var engine: GodEngine

    private var progress: Double {
        guard engine.transport.loopLengthFrames > 0 else { return 0 }
        return Double(engine.transport.position) / Double(engine.transport.loopLengthFrames)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track background
                Rectangle()
                    .fill(Theme.subtle)
                    .frame(height: 3)

                // Progress fill
                Rectangle()
                    .fill(Theme.blue)
                    .frame(width: geo.size.width * progress, height: 3)
            }
        }
        .frame(height: 3)
    }
}
```

**Step 2: Build**

Run: `cd /Users/brawny/god/GOD && swift build 2>&1`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add GOD/GOD/Views/LoopBarView.swift
git commit -m "feat: smooth blue loop progress bar"
```

---

### Task 6: Create SignalMeterView

**Files:**
- Create: `GOD/GOD/Views/SignalMeterView.swift`

**Step 1: Create SignalMeterView.swift**

```swift
import SwiftUI

struct SignalMeterView: View {
    let level: Float  // 0.0 to 1.0
    private let segments = 8

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { i in
                let threshold = Float(i) / Float(segments)
                RoundedRectangle(cornerRadius: 1)
                    .fill(level > threshold ? Theme.blue : Theme.subtle)
                    .frame(width: 6, height: 10)
            }
        }
    }
}
```

**Step 2: Build**

Run: `cd /Users/brawny/god/GOD && swift build 2>&1`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add GOD/GOD/Views/SignalMeterView.swift
git commit -m "feat: add signal meter view component"
```

---

### Task 7: Create ChannelRowView and replace PadGridView + LayerListView

**Files:**
- Create: `GOD/GOD/Views/ChannelRowView.swift`
- Delete: `GOD/GOD/Views/PadGridView.swift`
- Delete: `GOD/GOD/Views/LayerListView.swift`

**Step 1: Create ChannelRowView.swift**

```swift
import SwiftUI

struct ChannelListView: View {
    @ObservedObject var engine: GodEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<8, id: \.self) { i in
                ChannelRowView(
                    index: i,
                    layer: engine.layers[i],
                    pad: engine.padBank.pads[i],
                    signalLevel: engine.channelSignalLevels[i],
                    triggered: engine.channelTriggered[i]
                )
            }
        }
    }
}

struct ChannelRowView: View {
    let index: Int
    let layer: Layer
    let pad: Pad
    let signalLevel: Float
    let triggered: Bool

    private var hasContent: Bool {
        pad.sample != nil || !layer.hits.isEmpty
    }

    private var displayName: String {
        if pad.sample != nil { return pad.name }
        if !layer.hits.isEmpty { return layer.name }
        return "—"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Channel number
            Text("\(index + 1)")
                .foregroundColor(Theme.text)
                .frame(width: 16, alignment: .trailing)

            // Sample name
            Text(displayName)
                .foregroundColor(Theme.text)
                .frame(width: 80, alignment: .leading)

            // Active/muted indicator
            if hasContent {
                Text(layer.isMuted ? "○" : "●")
                    .foregroundColor(layer.isMuted ? Theme.text : Theme.blue)
            }

            // Signal meter (only when active and not muted)
            if hasContent && !layer.isMuted {
                SignalMeterView(level: signalLevel)
            }

            Spacer()
        }
        .font(Theme.mono)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(triggered ? Theme.text.opacity(0.15) : Color.clear)
        .animation(.easeOut(duration: 0.08), value: triggered)
    }
}
```

**Step 2: Delete old view files**

```bash
rm GOD/GOD/Views/PadGridView.swift GOD/GOD/Views/LayerListView.swift
```

**Step 3: Build**

Run: `cd /Users/brawny/god/GOD && swift build 2>&1`
Expected: Build fails — ContentView still references PadGridView and LayerListView. That's expected, we fix it in the next task.

**Step 4: Commit**

```bash
git add GOD/GOD/Views/ChannelRowView.swift
git add GOD/GOD/Views/PadGridView.swift GOD/GOD/Views/LayerListView.swift
git commit -m "feat: add channel row view, remove pad grid and layer list"
```

---

### Task 8: Rewrite CaptureIndicatorView — bold white/orange

**Files:**
- Modify: `GOD/GOD/Views/CaptureIndicatorView.swift`

**Step 1: Rewrite CaptureIndicatorView.swift**

```swift
import SwiftUI

struct CaptureIndicatorView: View {
    @ObservedObject var engine: GodEngine
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Text(engine.capture.state == .idle ? "○" : "◉")
                .foregroundColor(captureColor)
                .opacity(engine.capture.state == .recording ? (pulse ? 1.0 : 0.5) : 1.0)

            Text("GOD")
                .foregroundColor(captureColor)

            if engine.capture.state == .armed {
                Text("— armed")
                    .foregroundColor(Theme.orange)
            } else if engine.capture.state == .recording {
                Text("— recording")
                    .foregroundColor(Theme.orange)
            }
        }
        .font(Theme.mono)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var captureColor: Color {
        switch engine.capture.state {
        case .idle: return Theme.text
        case .armed: return Theme.orange
        case .recording: return Theme.orange
        }
    }
}
```

**Step 2: Build**

Run: `cd /Users/brawny/god/GOD && swift build 2>&1`
Expected: May still fail due to ContentView — that's fine

**Step 3: Commit**

```bash
git add GOD/GOD/Views/CaptureIndicatorView.swift
git commit -m "feat: bold white/orange capture indicator"
```

---

### Task 9: Update TipView — white text

**Files:**
- Modify: `GOD/GOD/Views/TipView.swift`

**Step 1: Update colors in TipView**

Change line 20 `Theme.dim` → `Theme.text` and line 24 `Theme.muted` → `Theme.subtle`:

```swift
import SwiftUI

struct TipView: View {
    @State private var tipDeck = TipDeck()
    @State private var currentTip = ""
    @State private var tipStartTime = Date()
    @State private var elapsed: Double = 0

    private let charInterval = 0.08
    private let cycleInterval = 12.0
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            let typewriter = TypewriterState(text: currentTip, charInterval: charInterval)
            let visible = typewriter.visibleText(elapsed: elapsed)

            Text("\"\(visible)\"")
                .font(Theme.monoSmall)
                .foregroundColor(Theme.text)

            if elapsed >= typewriter.totalDuration {
                Text("— claude")
                    .font(Theme.monoTiny)
                    .foregroundColor(Theme.blue)
            }
        }
        .onAppear { nextTip() }
        .onReceive(timer) { _ in
            elapsed = Date().timeIntervalSince(tipStartTime)
            let typewriter = TypewriterState(text: currentTip, charInterval: charInterval)
            if elapsed > typewriter.totalDuration + cycleInterval {
                nextTip()
            }
        }
    }

    private func nextTip() {
        currentTip = tipDeck.next()
        tipStartTime = Date()
        elapsed = 0
    }
}
```

**Step 2: Build**

Run: `cd /Users/brawny/god/GOD && swift build 2>&1`
Expected: May still fail due to ContentView

**Step 3: Commit**

```bash
git add GOD/GOD/Views/TipView.swift
git commit -m "feat: bright white tips with blue claude attribution"
```

---

### Task 10: Rewrite CommandInputView — hidden by default

**Files:**
- Modify: `GOD/GOD/Views/CommandInputView.swift`

**Step 1: Rewrite CommandInputView.swift**

```swift
import SwiftUI

struct CommandInputView: View {
    @ObservedObject var engine: GodEngine
    @Binding var isVisible: Bool
    @State private var command = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        if isVisible {
            HStack(spacing: 4) {
                Text(">")
                    .foregroundColor(Theme.blue)
                TextField("", text: $command)
                    .textFieldStyle(.plain)
                    .foregroundColor(Theme.text)
                    .focused($isFocused)
                    .onSubmit {
                        engine.executeCommand(command)
                        command = ""
                        isVisible = false
                    }
                    .onKeyPress(.escape) {
                        command = ""
                        isVisible = false
                        return .handled
                    }
            }
            .font(Theme.mono)
            .onAppear { isFocused = true }
            .onChange(of: isVisible) { _, newValue in
                if newValue { isFocused = true }
            }
        }
    }
}
```

**Step 2: Build**

Run: `cd /Users/brawny/god/GOD && swift build 2>&1`
Expected: Fails — ContentView passes wrong args. Fixed next task.

**Step 3: Commit**

```bash
git add GOD/GOD/Views/CommandInputView.swift
git commit -m "feat: hidden command input, shown with /, dismissed with ESC"
```

---

### Task 11: Create KeyReferenceOverlay

**Files:**
- Create: `GOD/GOD/Views/KeyReferenceOverlay.swift`

**Step 1: Create KeyReferenceOverlay.swift**

```swift
import SwiftUI

struct KeyReferenceOverlay: View {
    @Binding var isVisible: Bool

    private let shortcuts: [(key: String, action: String)] = [
        ("SPC", "play / stop"),
        ("G", "god capture"),
        ("M", "metronome"),
        ("↑", "bpm +1"),
        ("↓", "bpm -1"),
        ("1-8", "mute / unmute"),
        ("/", "command input"),
        ("ESC", "stop / dismiss"),
        ("?", "this help"),
    ]

    var body: some View {
        VStack(spacing: 12) {
            Text("KEYS")
                .font(Theme.monoLarge)
                .foregroundColor(Theme.text)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(shortcuts, id: \.key) { shortcut in
                    HStack(spacing: 16) {
                        Text(shortcut.key)
                            .foregroundColor(Theme.blue)
                            .frame(width: 50, alignment: .trailing)
                        Text(shortcut.action)
                            .foregroundColor(Theme.text)
                    }
                }
            }

            Text("press any key to close")
                .font(Theme.monoSmall)
                .foregroundColor(Theme.subtle)
                .padding(.top, 8)
        }
        .font(Theme.mono)
        .padding(40)
        .background(Theme.bg.opacity(0.95))
    }
}
```

**Step 2: Build**

Run: `cd /Users/brawny/god/GOD && swift build 2>&1`
Expected: Build succeeds

**Step 3: Commit**

```bash
git add GOD/GOD/Views/KeyReferenceOverlay.swift
git commit -m "feat: add key reference overlay"
```

---

### Task 12: Rewrite ContentView — wire everything together

**Files:**
- Modify: `GOD/GOD/ContentView.swift`

**Step 1: Rewrite ContentView.swift**

```swift
import SwiftUI

struct ContentView: View {
    @ObservedObject var engine: GodEngine
    @State private var showSetup = false
    @State private var showCommandInput = false
    @State private var showKeyReference = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 16) {
                // Title
                TitleView()
                    .padding(.top, 8)

                // Transport
                TransportView(engine: engine)

                // Loop bar
                LoopBarView(engine: engine)

                // Channels
                ChannelListView(engine: engine)
                    .padding(.vertical, 8)

                Spacer()

                // Capture indicator
                CaptureIndicatorView(engine: engine)

                // Tips
                TipView()
                    .padding(.vertical, 4)

                // Key strip
                Text("SPC play · G god · M metro · ↑↓ bpm · / cmd · ? keys")
                    .font(Theme.monoTiny)
                    .foregroundColor(Theme.subtle)

                // Command input (hidden by default)
                CommandInputView(engine: engine, isVisible: $showCommandInput)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 20)

            // Key reference overlay
            if showKeyReference {
                KeyReferenceOverlay(isVisible: $showKeyReference)
            }
        }
        .sheet(isPresented: $showSetup) {
            SetupView(engine: engine, isPresented: $showSetup)
                .frame(width: 500, height: 500)
        }
        .onKeyPress(.space) {
            guard !showCommandInput else { return .ignored }
            engine.togglePlay()
            return .handled
        }
        .onKeyPress("g") {
            guard !showCommandInput else { return .ignored }
            engine.toggleCapture()
            return .handled
        }
        .onKeyPress("m") {
            guard !showCommandInput else { return .ignored }
            engine.toggleMetronome()
            return .handled
        }
        .onKeyPress(.upArrow) {
            guard !showCommandInput else { return .ignored }
            engine.setBPM(engine.transport.bpm + 1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            guard !showCommandInput else { return .ignored }
            engine.setBPM(engine.transport.bpm - 1)
            return .handled
        }
        .onKeyPress(.escape) {
            if showCommandInput {
                showCommandInput = false
            } else if showKeyReference {
                showKeyReference = false
            } else {
                engine.stop()
            }
            return .handled
        }
        .onKeyPress("/") {
            guard !showCommandInput else { return .ignored }
            showCommandInput = true
            return .handled
        }
        .onKeyPress("?") {
            guard !showCommandInput else { return .ignored }
            showKeyReference.toggle()
            return .handled
        }
        .onKeyPress("1") { guard !showCommandInput else { return .ignored }; engine.toggleMute(layer: 0); return .handled }
        .onKeyPress("2") { guard !showCommandInput else { return .ignored }; engine.toggleMute(layer: 1); return .handled }
        .onKeyPress("3") { guard !showCommandInput else { return .ignored }; engine.toggleMute(layer: 2); return .handled }
        .onKeyPress("4") { guard !showCommandInput else { return .ignored }; engine.toggleMute(layer: 3); return .handled }
        .onKeyPress("5") { guard !showCommandInput else { return .ignored }; engine.toggleMute(layer: 4); return .handled }
        .onKeyPress("6") { guard !showCommandInput else { return .ignored }; engine.toggleMute(layer: 5); return .handled }
        .onKeyPress("7") { guard !showCommandInput else { return .ignored }; engine.toggleMute(layer: 6); return .handled }
        .onKeyPress("8") { guard !showCommandInput else { return .ignored }; engine.toggleMute(layer: 7); return .handled }
    }
}
```

**Step 2: Build the full project**

Run: `cd /Users/brawny/god/GOD && swift build 2>&1`
Expected: Build succeeds — all views are now wired correctly

**Step 3: Run all tests**

Run: `cd /Users/brawny/god/GOD && swift test 2>&1`
Expected: All tests pass

**Step 4: Commit**

```bash
git add GOD/GOD/ContentView.swift
git commit -m "feat: wire up redesigned UI with keyboard-only controls"
```

---

### Task 13: Final build, run, and verify

**Step 1: Clean build**

Run: `cd /Users/brawny/god/GOD && swift build 2>&1`
Expected: Build succeeds with no warnings (except the entitlements warning)

**Step 2: Run all tests**

Run: `cd /Users/brawny/god/GOD && swift test 2>&1`
Expected: All 30 tests pass

**Step 3: Run the app**

Run: `cd /Users/brawny/god/GOD && swift run &`
Expected: GOD window opens with:
- Breathing "G   O   D" title in white
- Bold white transport strip with play state
- Blue loop progress bar
- 8 channel rows showing numbers and dashes in white
- White GOD capture indicator
- Typewriter tips in white
- Key strip at bottom
- No command input visible (press `/` to reveal)

**Step 4: Manual verification checklist**
- [ ] Title breathes (opacity animates)
- [ ] Press SPC — transport shows ▶ in blue, loop bar moves
- [ ] Press M — metronome toggles, "♩ on/off" updates
- [ ] Press ↑/↓ — BPM changes
- [ ] Press / — command input appears with blue `>`
- [ ] Type "bpm 140" + Enter — BPM updates, input hides
- [ ] Press ? — key reference overlay appears
- [ ] Press ESC — overlay/input dismisses, or stops playback
- [ ] Press 1-8 — channels mute/unmute (● ↔ ○)
- [ ] Press G — capture cycles idle→armed→recording

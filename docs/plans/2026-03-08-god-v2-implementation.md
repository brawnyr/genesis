# GOD v2 — Native macOS App Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rewrite GOD as a pure SwiftUI + CoreAudio + CoreMIDI native macOS app for loop-stacking beat production.

**Architecture:** Single-process SwiftUI app. GodEngine (ObservableObject) holds all state. CoreAudio render callback mixes layers in real-time. CoreMIDI receives MiniLab 3 pad input. SwiftUI views observe published state and re-render automatically.

**Tech Stack:** Swift, SwiftUI, AVFoundation (AVAudioEngine), CoreMIDI, AudioToolbox

---

### Task 1: Xcode Project Scaffold

**Files:**
- Create: `GOD/GOD.xcodeproj` (via Xcode CLI)
- Create: `GOD/GOD/GODApp.swift`
- Create: `GOD/GOD/ContentView.swift`
- Create: `GOD/GOD/Info.plist`

**Step 1: Create Xcode project**

```bash
cd ~/god
mkdir -p GOD/GOD
```

**Step 2: Create app entry point**

```swift
// GOD/GOD/GODApp.swift
import SwiftUI

@main
struct GODApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 700)
    }
}
```

**Step 3: Create placeholder ContentView**

```swift
// GOD/GOD/ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color(red: 0.102, green: 0.098, blue: 0.090) // #1a1917
                .ignoresSafeArea()
            Text("G O D")
                .font(.custom("JetBrains Mono", size: 24))
                .foregroundColor(Color(red: 0.831, green: 0.812, blue: 0.776)) // #d4cfc6
        }
    }
}
```

**Step 4: Create Package.swift for SPM-based build (alternative to .xcodeproj)**

Since we want to stay CLI-friendly, use a Swift Package with an executable target:

```swift
// GOD/Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GOD",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GOD",
            path: "GOD"
        ),
        .testTarget(
            name: "GODTests",
            dependencies: ["GOD"],
            path: "Tests"
        )
    ]
)
```

**Step 5: Verify it builds and shows the window**

```bash
cd ~/god/GOD
swift build
swift run GOD
```

Expected: dark window with "G O D" text appears.

**Step 6: Commit**

```bash
git add GOD/
git commit -m "feat: scaffold GOD v2 SwiftUI app"
```

---

### Task 2: Transport Model

**Files:**
- Create: `GOD/GOD/Models/Transport.swift`
- Create: `GOD/Tests/TransportTests.swift`

**Step 1: Write failing tests**

```swift
// GOD/Tests/TransportTests.swift
import Testing
@testable import GOD

@Test func transportDefaults() {
    let transport = Transport()
    #expect(transport.bpm == 120)
    #expect(transport.barCount == 4)
    #expect(transport.position == 0)
    #expect(transport.isPlaying == false)
}

@Test func transportLoopLength() {
    let transport = Transport()
    // 4 bars × 4 beats × (60/120) × 44100 = 16 × 0.5 × 44100 = 352800
    #expect(transport.loopLengthFrames == 352800)
}

@Test func transportAdvanceWraps() {
    var transport = Transport()
    transport.position = 352790
    let wrapped = transport.advance(frames: 20)
    #expect(wrapped == true)
    #expect(transport.position == 10)
}

@Test func transportAdvanceNoWrap() {
    var transport = Transport()
    transport.position = 100
    let wrapped = transport.advance(frames: 50)
    #expect(wrapped == false)
    #expect(transport.position == 150)
}

@Test func transportBPMClamps() {
    var transport = Transport()
    transport.bpm = 300
    #expect(transport.bpm == 300)
    transport.bpm = 0
    #expect(transport.bpm == 1) // minimum 1
}

@Test func transportBarCountValidation() {
    var transport = Transport()
    transport.barCount = 2
    #expect(transport.barCount == 2)
    transport.barCount = 3 // invalid
    #expect(transport.barCount == 2) // unchanged
}
```

**Step 2: Run tests to verify they fail**

```bash
cd ~/god/GOD
swift test
```

Expected: FAIL — `Transport` not defined.

**Step 3: Implement Transport**

```swift
// GOD/GOD/Models/Transport.swift
import Foundation

struct Transport {
    static let sampleRate: Double = 44100.0
    private static let validBarCounts: Set<Int> = [1, 2, 4]

    var bpm: Int = 120 {
        didSet { bpm = max(1, bpm) }
    }

    var barCount: Int = 4 {
        didSet {
            if !Self.validBarCounts.contains(barCount) {
                barCount = oldValue
            }
        }
    }

    var position: Int = 0
    var isPlaying: Bool = false

    var loopLengthFrames: Int {
        let beatsPerLoop = Double(barCount * 4)
        let secondsPerBeat = 60.0 / Double(bpm)
        return Int(beatsPerLoop * secondsPerBeat * Self.sampleRate)
    }

    /// Advance position by frames. Returns true if loop wrapped.
    mutating func advance(frames: Int) -> Bool {
        position += frames
        if position >= loopLengthFrames {
            position -= loopLengthFrames
            return true
        }
        return false
    }

    mutating func reset() {
        position = 0
        isPlaying = false
    }
}
```

**Step 4: Run tests to verify they pass**

```bash
cd ~/god/GOD
swift test
```

Expected: all PASS.

**Step 5: Commit**

```bash
git add GOD/GOD/Models/Transport.swift GOD/Tests/TransportTests.swift
git commit -m "feat: add Transport model with loop timing"
```

---

### Task 3: Sample & Voice Models

**Files:**
- Create: `GOD/GOD/Models/Sample.swift`
- Create: `GOD/GOD/Models/Voice.swift`
- Create: `GOD/Tests/VoiceTests.swift`

**Step 1: Write failing tests**

```swift
// GOD/Tests/VoiceTests.swift
import Testing
@testable import GOD

@Test func voicePlayback() {
    let data: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
    let sample = Sample(name: "test", data: data, sampleRate: 44100)
    var voice = Voice(sample: sample, velocity: 1.0)

    var buffer = [Float](repeating: 0, count: 3)
    let finished = voice.fill(into: &buffer, count: 3)
    #expect(finished == false)
    #expect(buffer[0] == 0.1)
    #expect(buffer[1] == 0.2)
    #expect(buffer[2] == 0.3)
}

@Test func voiceFinishes() {
    let data: [Float] = [0.1, 0.2]
    let sample = Sample(name: "test", data: data, sampleRate: 44100)
    var voice = Voice(sample: sample, velocity: 1.0)

    var buffer = [Float](repeating: 0, count: 4)
    let finished = voice.fill(into: &buffer, count: 4)
    #expect(finished == true)
    #expect(buffer[0] == 0.1)
    #expect(buffer[1] == 0.2)
    #expect(buffer[2] == 0)
    #expect(buffer[3] == 0)
}

@Test func voiceVelocityScaling() {
    let data: [Float] = [1.0, 1.0]
    let sample = Sample(name: "test", data: data, sampleRate: 44100)
    var voice = Voice(sample: sample, velocity: 0.5)

    var buffer = [Float](repeating: 0, count: 2)
    _ = voice.fill(into: &buffer, count: 2)
    #expect(buffer[0] == 0.5)
}
```

**Step 2: Run tests to verify they fail**

```bash
swift test
```

**Step 3: Implement Sample and Voice**

```swift
// GOD/GOD/Models/Sample.swift
import Foundation
import AVFoundation

struct Sample {
    let name: String
    let data: [Float]
    let sampleRate: Double

    /// Load from audio file (WAV, MP3, FLAC, etc.)
    static func load(from url: URL) throws -> Sample {
        let file = try AVAudioFile(forReading: url)
        let format = AVAudioFormat(standardFormatWithSampleRate: file.fileFormat.sampleRate, channels: 1)!
        let frameCount = AVAudioFrameCount(file.length)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        try file.read(into: buffer)

        let floatData = Array(UnsafeBufferPointer(
            start: buffer.floatChannelData![0],
            count: Int(buffer.frameLength)
        ))

        let name = url.deletingPathExtension().lastPathComponent
        return Sample(name: name, data: floatData, sampleRate: file.fileFormat.sampleRate)
    }
}
```

```swift
// GOD/GOD/Models/Voice.swift
import Foundation

struct Voice {
    let sample: Sample
    let velocity: Float
    var position: Int = 0

    /// Mix samples into buffer additively. Returns true when finished.
    mutating func fill(into buffer: inout [Float], count: Int) -> Bool {
        let remaining = sample.data.count - position
        let toWrite = min(count, remaining)

        for i in 0..<toWrite {
            buffer[i] += sample.data[position + i] * velocity
        }

        position += toWrite
        return position >= sample.data.count
    }
}
```

**Step 4: Run tests**

```bash
swift test
```

Expected: all PASS.

**Step 5: Commit**

```bash
git add GOD/GOD/Models/Sample.swift GOD/GOD/Models/Voice.swift GOD/Tests/VoiceTests.swift
git commit -m "feat: add Sample and Voice models for audio playback"
```

---

### Task 4: Layer & Hit Models

**Files:**
- Create: `GOD/GOD/Models/Layer.swift`
- Create: `GOD/Tests/LayerTests.swift`

**Step 1: Write failing tests**

```swift
// GOD/Tests/LayerTests.swift
import Testing
@testable import GOD

@Test func layerRecordsHits() {
    var layer = Layer(index: 0, name: "KICK")
    layer.addHit(at: 1000, velocity: 100)
    layer.addHit(at: 5000, velocity: 80)
    #expect(layer.hits.count == 2)
}

@Test func layerHitsInRange() {
    var layer = Layer(index: 0, name: "KICK")
    layer.addHit(at: 100, velocity: 100)
    layer.addHit(at: 500, velocity: 80)
    layer.addHit(at: 1000, velocity: 90)

    let hits = layer.hits(inRange: 50..<600)
    #expect(hits.count == 2)
    #expect(hits[0].position == 100)
    #expect(hits[1].position == 500)
}

@Test func layerClear() {
    var layer = Layer(index: 0, name: "KICK")
    layer.addHit(at: 100, velocity: 100)
    layer.addHit(at: 200, velocity: 80)
    layer.clear()
    #expect(layer.hits.count == 0)
}

@Test func layerMuteToggle() {
    var layer = Layer(index: 0, name: "KICK")
    #expect(layer.isMuted == false)
    layer.isMuted.toggle()
    #expect(layer.isMuted == true)
}
```

**Step 2: Run tests to verify they fail**

```bash
swift test
```

**Step 3: Implement Layer**

```swift
// GOD/GOD/Models/Layer.swift
import Foundation

struct Hit {
    let position: Int  // frame offset in loop
    let velocity: Int  // 0-127
}

struct Layer {
    let index: Int
    var name: String
    var hits: [Hit] = []
    var isMuted: Bool = false

    mutating func addHit(at position: Int, velocity: Int) {
        hits.append(Hit(position: position, velocity: velocity))
        hits.sort { $0.position < $1.position }
    }

    func hits(inRange range: Range<Int>) -> [Hit] {
        hits.filter { range.contains($0.position) }
    }

    mutating func clear() {
        hits.removeAll()
    }
}
```

**Step 4: Run tests**

```bash
swift test
```

Expected: all PASS.

**Step 5: Commit**

```bash
git add GOD/GOD/Models/Layer.swift GOD/Tests/LayerTests.swift
git commit -m "feat: add Layer and Hit models for per-pad recording"
```

---

### Task 5: Pad Model & Persistence

**Files:**
- Create: `GOD/GOD/Models/Pad.swift`
- Create: `GOD/Tests/PadTests.swift`

**Step 1: Write failing tests**

```swift
// GOD/Tests/PadTests.swift
import Testing
import Foundation
@testable import GOD

@Test func padMIDINoteMapping() {
    let pads = PadBank()
    #expect(pads.padIndex(forNote: 36) == 0)
    #expect(pads.padIndex(forNote: 43) == 7)
    #expect(pads.padIndex(forNote: 44) == nil)
    #expect(pads.padIndex(forNote: 35) == nil)
}

@Test func padSampleAssignment() {
    var pads = PadBank()
    let sample = Sample(name: "kick", data: [0.1, 0.2], sampleRate: 44100)
    pads.assign(sample: sample, toPad: 0)
    #expect(pads.pads[0].sample?.name == "kick")
}

@Test func padConfigSerialization() {
    var pads = PadBank()
    pads.pads[0].samplePath = "/path/to/kick.wav"
    pads.pads[0].name = "KICK"
    let data = try! JSONEncoder().encode(pads.config)
    let decoded = try! JSONDecoder().decode(PadConfig.self, from: data)
    #expect(decoded.assignments[0]?.path == "/path/to/kick.wav")
}
```

**Step 2: Run tests to verify they fail**

```bash
swift test
```

**Step 3: Implement Pad and PadBank**

```swift
// GOD/GOD/Models/Pad.swift
import Foundation

struct Pad {
    let index: Int
    let midiNote: Int
    var name: String
    var sample: Sample?
    var samplePath: String?
}

struct PadConfig: Codable {
    var assignments: [Int: PadAssignment] = [:]

    struct PadAssignment: Codable {
        let path: String
        let name: String
    }
}

struct PadBank {
    static let baseNote = 36
    static let padCount = 8

    var pads: [Pad] = (0..<8).map { i in
        Pad(index: i, midiNote: baseNote + i, name: "PAD \(i + 1)")
    }

    func padIndex(forNote note: Int) -> Int? {
        let index = note - Self.baseNote
        guard index >= 0, index < Self.padCount else { return nil }
        return index
    }

    mutating func assign(sample: Sample, toPad index: Int) {
        guard index >= 0, index < Self.padCount else { return }
        pads[index].sample = sample
        pads[index].name = sample.name.uppercased()
    }

    var config: PadConfig {
        var cfg = PadConfig()
        for pad in pads {
            if let path = pad.samplePath {
                cfg.assignments[pad.index] = PadConfig.PadAssignment(
                    path: path, name: pad.name
                )
            }
        }
        return cfg
    }

    static let configURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".god")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pads.json")
    }()

    func save() throws {
        let data = try JSONEncoder().encode(config)
        try data.write(to: Self.configURL)
    }

    mutating func loadConfig() throws {
        let data = try Data(contentsOf: Self.configURL)
        let cfg = try JSONDecoder().decode(PadConfig.self, from: data)
        for (index, assignment) in cfg.assignments {
            let url = URL(fileURLWithPath: assignment.path)
            if let sample = try? Sample.load(from: url) {
                pads[index].sample = sample
                pads[index].samplePath = assignment.path
                pads[index].name = assignment.name
            }
        }
    }
}
```

**Step 4: Run tests**

```bash
swift test
```

Expected: all PASS.

**Step 5: Commit**

```bash
git add GOD/GOD/Models/Pad.swift GOD/Tests/PadTests.swift
git commit -m "feat: add Pad and PadBank with persistence"
```

---

### Task 6: Metronome

**Files:**
- Create: `GOD/GOD/Models/Metronome.swift`
- Create: `GOD/Tests/MetronomeTests.swift`

**Step 1: Write failing tests**

```swift
// GOD/Tests/MetronomeTests.swift
import Testing
@testable import GOD

@Test func metronomeClickGeneration() {
    let click = Metronome.generateClick(isDownbeat: false, sampleRate: 44100)
    #expect(click.count > 0)
    #expect(click.count <= 4410) // max ~100ms
}

@Test func metronomeDownbeatLouder() {
    let normal = Metronome.generateClick(isDownbeat: false, sampleRate: 44100)
    let downbeat = Metronome.generateClick(isDownbeat: true, sampleRate: 44100)
    let normalPeak = normal.map { abs($0) }.max()!
    let downbeatPeak = downbeat.map { abs($0) }.max()!
    #expect(downbeatPeak > normalPeak)
}

@Test func metronomeBeatPosition() {
    let met = Metronome()
    // At 120 BPM, beat length = 22050 frames
    #expect(met.beatLengthFrames(bpm: 120, sampleRate: 44100) == 22050)
}
```

**Step 2: Run tests to verify they fail**

```bash
swift test
```

**Step 3: Implement Metronome**

```swift
// GOD/GOD/Models/Metronome.swift
import Foundation

struct Metronome {
    var isOn: Bool = true
    var volume: Float = 0.5

    func beatLengthFrames(bpm: Int, sampleRate: Double) -> Int {
        Int(60.0 / Double(bpm) * sampleRate)
    }

    /// Generate a click waveform. Downbeats are higher pitch + louder.
    static func generateClick(isDownbeat: Bool, sampleRate: Double) -> [Float] {
        let duration = 0.02 // 20ms
        let frameCount = Int(duration * sampleRate)
        let frequency: Double = isDownbeat ? 1500.0 : 1000.0
        let amplitude: Float = isDownbeat ? 0.8 : 0.4

        var buffer = [Float](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let envelope = Float(exp(-t * 150.0)) // fast decay
            let sine = Float(sin(2.0 * .pi * frequency * t))
            buffer[i] = sine * envelope * amplitude
        }
        return buffer
    }
}
```

**Step 4: Run tests**

```bash
swift test
```

Expected: all PASS.

**Step 5: Commit**

```bash
git add GOD/GOD/Models/Metronome.swift GOD/Tests/MetronomeTests.swift
git commit -m "feat: add Metronome with procedural click generation"
```

---

### Task 7: GodCapture

**Files:**
- Create: `GOD/GOD/Models/GodCapture.swift`
- Create: `GOD/Tests/GodCaptureTests.swift`

**Step 1: Write failing tests**

```swift
// GOD/Tests/GodCaptureTests.swift
import Testing
@testable import GOD

@Test func captureStateTransitions() {
    var capture = GodCapture()
    #expect(capture.state == .idle)

    capture.toggle()
    #expect(capture.state == .armed)

    capture.onLoopBoundary()
    #expect(capture.state == .recording)

    capture.toggle()
    #expect(capture.state == .idle)
}

@Test func captureAccumulatesBuffers() {
    var capture = GodCapture()
    capture.toggle() // armed
    capture.onLoopBoundary() // recording

    let buffer: [Float] = [0.1, 0.2, 0.3]
    capture.append(buffer: buffer)
    capture.append(buffer: buffer)
    #expect(capture.accumulatedFrames == 6)
}
```

**Step 2: Run tests to verify they fail**

```bash
swift test
```

**Step 3: Implement GodCapture**

```swift
// GOD/GOD/Models/GodCapture.swift
import Foundation
import AVFoundation

struct GodCapture {
    enum State {
        case idle, armed, recording
    }

    var state: State = .idle
    private var buffers: [[Float]] = []

    var accumulatedFrames: Int {
        buffers.reduce(0) { $0 + $1.count }
    }

    mutating func toggle() {
        switch state {
        case .idle:
            state = .armed
        case .armed:
            state = .idle
        case .recording:
            state = .idle
            writeAndReset()
        }
    }

    mutating func onLoopBoundary() {
        if state == .armed {
            state = .recording
            buffers = []
        }
    }

    mutating func append(buffer: [Float]) {
        guard state == .recording else { return }
        buffers.append(buffer)
    }

    private mutating func writeAndReset() {
        guard !buffers.isEmpty else { return }
        let allSamples = buffers.flatMap { $0 }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "GOD_\(formatter.string(from: Date())).wav"

        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".god/captures")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(filename)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        if let file = try? AVAudioFile(forWriting: url, settings: format.settings) {
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(allSamples.count))!
            buffer.frameLength = AVAudioFrameCount(allSamples.count)
            allSamples.withUnsafeBufferPointer { ptr in
                buffer.floatChannelData![0].update(from: ptr.baseAddress!, count: allSamples.count)
            }
            try? file.write(from: buffer)
        }

        buffers = []
    }
}
```

**Step 4: Run tests**

```bash
swift test
```

Expected: all PASS.

**Step 5: Commit**

```bash
git add GOD/GOD/Models/GodCapture.swift GOD/Tests/GodCaptureTests.swift
git commit -m "feat: add GodCapture state machine with WAV output"
```

---

### Task 8: GodEngine — Core Orchestrator

**Files:**
- Create: `GOD/GOD/Engine/GodEngine.swift`
- Create: `GOD/Tests/GodEngineTests.swift`

**Step 1: Write failing tests**

```swift
// GOD/Tests/GodEngineTests.swift
import Testing
@testable import GOD

@Test func engineInitialState() {
    let engine = GodEngine()
    #expect(engine.transport.bpm == 120)
    #expect(engine.transport.isPlaying == false)
    #expect(engine.layers.count == 8)
    #expect(engine.capture.state == .idle)
}

@Test func engineTogglePlay() {
    let engine = GodEngine()
    engine.togglePlay()
    #expect(engine.transport.isPlaying == true)
    engine.togglePlay()
    #expect(engine.transport.isPlaying == false)
}

@Test func engineSetBPM() {
    let engine = GodEngine()
    engine.setBPM(140)
    #expect(engine.transport.bpm == 140)
}

@Test func engineToggleMute() {
    let engine = GodEngine()
    engine.toggleMute(layer: 0)
    #expect(engine.layers[0].isMuted == true)
    engine.toggleMute(layer: 0)
    #expect(engine.layers[0].isMuted == false)
}

@Test func engineClearLayer() {
    let engine = GodEngine()
    engine.layers[0].addHit(at: 100, velocity: 100)
    engine.clearLayer(0)
    #expect(engine.layers[0].hits.count == 0)
}
```

**Step 2: Run tests to verify they fail**

```bash
swift test
```

**Step 3: Implement GodEngine**

```swift
// GOD/GOD/Engine/GodEngine.swift
import Foundation
import Combine

@MainActor
class GodEngine: ObservableObject {
    @Published var transport = Transport()
    @Published var layers: [Layer] = (0..<8).map { Layer(index: $0, name: "PAD \($0 + 1)") }
    @Published var padBank = PadBank()
    @Published var metronome = Metronome()
    @Published var capture = GodCapture()

    // Active voices for audio mixing
    var voices: [Voice] = []

    func togglePlay() {
        transport.isPlaying.toggle()
        if !transport.isPlaying {
            transport.position = 0
            voices.removeAll()
        }
    }

    func stop() {
        transport.isPlaying = false
        transport.position = 0
        voices.removeAll()
    }

    func setBPM(_ bpm: Int) {
        transport.bpm = bpm
    }

    func toggleMute(layer index: Int) {
        guard index >= 0, index < layers.count else { return }
        layers[index].isMuted.toggle()
    }

    func clearLayer(_ index: Int) {
        guard index >= 0, index < layers.count else { return }
        layers[index].clear()
    }

    func toggleCapture() {
        capture.toggle()
    }

    func toggleMetronome() {
        metronome.isOn.toggle()
    }

    /// Called from MIDI callback when a pad is hit
    func onPadHit(note: Int, velocity: Int) {
        guard transport.isPlaying,
              let padIndex = padBank.padIndex(forNote: note),
              let sample = padBank.pads[padIndex].sample else { return }

        // Record hit into layer
        layers[padIndex].addHit(at: transport.position, velocity: velocity)
        layers[padIndex].name = padBank.pads[padIndex].name

        // Trigger immediate playback
        let vel = Float(velocity) / 127.0
        voices.append(Voice(sample: sample, velocity: vel))
    }

    /// Process audio block — called from audio render callback
    func processBlock(frameCount: Int) -> [Float] {
        var output = [Float](repeating: 0, count: frameCount)
        guard transport.isPlaying else { return output }

        let startPos = transport.position

        // Check each layer for hits in this block's range
        for layer in layers where !layer.isMuted {
            let endPos = startPos + frameCount
            let hits: [Hit]

            if endPos <= transport.loopLengthFrames {
                hits = layer.hits(inRange: startPos..<endPos)
            } else {
                // Wrapping around loop boundary
                let beforeWrap = layer.hits(inRange: startPos..<transport.loopLengthFrames)
                let afterWrap = layer.hits(inRange: 0..<(endPos - transport.loopLengthFrames))
                hits = beforeWrap + afterWrap
            }

            for hit in hits {
                if let padIndex = (0..<8).first(where: { layers[$0].index == layer.index }),
                   let sample = padBank.pads[padIndex].sample {
                    let vel = Float(hit.velocity) / 127.0
                    voices.append(Voice(sample: sample, velocity: vel))
                }
            }
        }

        // Metronome
        if metronome.isOn {
            let beatLen = metronome.beatLengthFrames(bpm: transport.bpm, sampleRate: Transport.sampleRate)
            for i in 0..<frameCount {
                let frameInLoop = (startPos + i) % transport.loopLengthFrames
                if frameInLoop % beatLen == 0 {
                    let isDownbeat = frameInLoop == 0
                    let click = Metronome.generateClick(isDownbeat: isDownbeat, sampleRate: Transport.sampleRate)
                    var clickVoice = Voice(
                        sample: Sample(name: "click", data: click, sampleRate: Transport.sampleRate),
                        velocity: metronome.volume
                    )
                    voices.append(clickVoice)
                }
            }
        }

        // Mix all active voices
        voices.removeAll { voice in
            var v = voice
            let done = v.fill(into: &output, count: frameCount)
            return done
        }

        // Capture
        if capture.state == .recording {
            capture.append(buffer: output)
        }

        // Advance transport
        let wrapped = transport.advance(frames: frameCount)
        if wrapped {
            capture.onLoopBoundary()
        }

        return output
    }

    /// Parse and execute a text command
    func executeCommand(_ input: String) {
        let parts = input.lowercased().trimmingCharacters(in: .whitespaces).split(separator: " ")
        guard let cmd = parts.first else { return }

        switch cmd {
        case "play":
            if !transport.isPlaying { togglePlay() }
        case "stop":
            stop()
        case "god":
            toggleCapture()
        case "bpm":
            if let val = parts.dropFirst().first, let bpm = Int(val) {
                setBPM(bpm)
            }
        case "mute":
            if let val = parts.dropFirst().first, let idx = Int(val) {
                if idx >= 1, idx <= 8 { toggleMute(layer: idx - 1) }
            }
        case "unmute":
            if let val = parts.dropFirst().first, let idx = Int(val) {
                if idx >= 1, idx <= 8, layers[idx - 1].isMuted {
                    toggleMute(layer: idx - 1)
                }
            }
        case "clear":
            if let val = parts.dropFirst().first, let idx = Int(val) {
                if idx >= 1, idx <= 8 { clearLayer(idx - 1) }
            }
        default:
            break
        }
    }
}
```

**Step 4: Run tests**

```bash
swift test
```

Expected: all PASS.

**Step 5: Commit**

```bash
git add GOD/GOD/Engine/GodEngine.swift GOD/Tests/GodEngineTests.swift
git commit -m "feat: add GodEngine orchestrator with command parsing"
```

---

### Task 9: CoreAudio Integration

**Files:**
- Create: `GOD/GOD/Engine/AudioManager.swift`

This task has no unit tests — CoreAudio requires a running audio session and real hardware. Manual testing only.

**Step 1: Implement AudioManager**

```swift
// GOD/GOD/Engine/AudioManager.swift
import AVFoundation

class AudioManager {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
        // This closure gets replaced in setup
        return noErr
    }
    private weak var godEngine: GodEngine?

    init(engine: GodEngine) {
        self.godEngine = engine
    }

    func start() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

        let sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let engine = self?.godEngine else { return noErr }

            let output = engine.processBlock(frameCount: Int(frameCount))

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = ablPointer[0]
            let ptr = buffer.mData?.assumingMemoryBound(to: Float.self)

            for i in 0..<Int(frameCount) {
                if i < output.count {
                    ptr?[i] = output[i]
                } else {
                    ptr?[i] = 0
                }
            }

            return noErr
        }

        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: audioEngine.mainMixerNode, format: format)

        try audioEngine.start()
    }

    func stop() {
        audioEngine.stop()
    }
}
```

**Step 2: Verify it compiles**

```bash
swift build
```

Expected: builds without errors.

**Step 3: Commit**

```bash
git add GOD/GOD/Engine/AudioManager.swift
git commit -m "feat: add CoreAudio integration via AVAudioSourceNode"
```

---

### Task 10: CoreMIDI Integration

**Files:**
- Create: `GOD/GOD/Engine/MIDIManager.swift`

No unit tests — requires MIDI hardware. Manual testing only.

**Step 1: Implement MIDIManager**

```swift
// GOD/GOD/Engine/MIDIManager.swift
import CoreMIDI
import Foundation

class MIDIManager {
    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private weak var engine: GodEngine?

    @Published var connectedDevice: String = "None"

    init(engine: GodEngine) {
        self.engine = engine
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
            let words = Mirror(reflecting: packet.words).children.map { $0.value as! UInt32 }
            let word = words[0]

            let status = (word >> 16) & 0xF0
            let note = Int((word >> 8) & 0x7F)
            let velocity = Int(word & 0x7F)

            if status == 0x90 && velocity > 0 { // note on
                DispatchQueue.main.async { [weak self] in
                    self?.engine?.onPadHit(note: note, velocity: velocity)
                }
            }

            packet = MIDIEventPacketNext(&packet).pointee
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

**Step 2: Verify it compiles**

```bash
swift build
```

Expected: builds without errors.

**Step 3: Commit**

```bash
git add GOD/GOD/Engine/MIDIManager.swift
git commit -m "feat: add CoreMIDI integration with MiniLab auto-detect"
```

---

### Task 11: Tips System

**Files:**
- Create: `GOD/GOD/Models/Tips.swift`
- Create: `GOD/Tests/TipsTests.swift`

**Step 1: Write failing tests**

```swift
// GOD/Tests/TipsTests.swift
import Testing
@testable import GOD

@Test func tipsDeckShuffles() {
    var deck = TipDeck()
    let first = deck.next()
    #expect(!first.isEmpty)
}

@Test func tipsDeckNoRepeatsUntilExhausted() {
    var deck = TipDeck()
    var seen: Set<String> = []
    let total = TipDeck.allTips.count
    for _ in 0..<total {
        let tip = deck.next()
        #expect(!seen.contains(tip), "Duplicate tip before deck exhausted")
        seen.insert(tip)
    }
    // After exhaustion, next call reshuffles — should still return a tip
    let afterReshuffle = deck.next()
    #expect(!afterReshuffle.isEmpty)
}

@Test func typewriterProgress() {
    let tw = TypewriterState(text: "hello", charInterval: 0.1)
    #expect(tw.visibleText(elapsed: 0) == "")
    #expect(tw.visibleText(elapsed: 0.25) == "he")
    #expect(tw.visibleText(elapsed: 1.0) == "hello")
}
```

**Step 2: Run tests to verify they fail**

```bash
swift test
```

**Step 3: Implement Tips**

```swift
// GOD/GOD/Models/Tips.swift
import Foundation

struct TipDeck {
    private var queue: [Int] = []

    static let allTips: [String] = [
        // Aseprite
        "in aseprite, hold shift while drawing to make a straight line",
        "aseprite's onion skin lets you see previous frames while animating",
        "ctrl+shift+h in aseprite toggles the grid overlay",
        "in aseprite, press b for brush tool, e for eraser, g for paint bucket",
        "aseprite can export sprite sheets — file > export sprite sheet",

        // macOS
        "cmd+shift+4 then space lets you screenshot a specific window",
        "cmd+option+esc opens force quit on mac",
        "option+click the green button to maximize without full screen",
        "cmd+shift+. shows hidden files in Finder",
        "three-finger drag on trackpad moves windows without clicking",

        // Terminal
        "ctrl+r in terminal lets you reverse-search through your command history",
        "!! repeats the last command — sudo !! is your friend",
        "cmd+k clears your terminal buffer completely, not just the screen",
        "you can pipe anything to pbcopy to copy to clipboard on mac",
        "ctrl+a jumps to the start of the line, ctrl+e to the end",

        // Zed
        "cmd+p in zed opens the file finder",
        "cmd+shift+p opens the command palette in zed",
        "option+up/down moves the current line in zed",
        "cmd+d selects the next occurrence in zed for multi-cursor editing",
        "cmd+shift+l selects all occurrences in zed",

        // Claude Code
        "/init creates a CLAUDE.md file for your project",
        "claude code remembers context from your CLAUDE.md across sessions",
        "you can pipe files into claude code with cat file.py | claude",
        "use /compact to compress conversation context when it gets long",
        "claude code can read images — just pass the file path",

        // CS trivia
        "the term 'bug' came from an actual moth found at Harvard in 1947",
        "a hash map is just an array wearing a trench coat pretending to be smart",
        "the internet runs on BGP and it's basically held together by trust and hope",
        "in floating point, 0.1 + 0.2 != 0.3 because binary can't represent those decimals exactly",
        "git was written by Linus Torvalds in about 10 days because he was annoyed",
        "TCP's three-way handshake is basically two computers saying 'hey' 'hey' 'ok cool'",
        "the first computer mouse was made of wood",
        "there are more possible chess games than atoms in the observable universe",
        "the @ symbol in email was chosen because it was the least-used key on the keyboard",
        "a kilobyte is 1024 bytes because computers think in powers of 2, not 10",

        // Music production
        "sidechain compression is basically the kick telling everything else to duck",
        "most hip-hop drums sit between 80-100 BPM in half-time feel",
        "layering a clap with a snare adds body without losing the crack",
        "high-passing your kicks around 30hz removes sub-rumble you can't hear anyway",
        "a loop that sounds boring solo might be exactly what the mix needs",
        "the MPC was designed so you could play drums like a keyboard player",
        "J Dilla's secret was making quantized beats feel drunk",
        "vinyl crackle is just noise but it makes everything feel warmer",
        "the 808 kick is actually a sine wave with a pitch envelope",
        "reverb on a snare: a little adds space, a lot adds vibe",
        "swing is just delaying every other note by a few milliseconds",
        "four-on-the-floor kick + offbeat hi-hat = instant house music",
        "the TR-808 was a commercial failure before hip-hop saved it",
        "sampling a sound and pitching it down makes everything sound heavier",
        "sometimes the best production move is deleting something",
    ]

    mutating func next() -> String {
        if queue.isEmpty {
            queue = Array(0..<Self.allTips.count)
            queue.shuffle()
        }
        return Self.allTips[queue.removeLast()]
    }
}

struct TypewriterState {
    let text: String
    let charInterval: Double // seconds per character

    func visibleText(elapsed: Double) -> String {
        let charCount = min(Int(elapsed / charInterval), text.count)
        return String(text.prefix(charCount))
    }

    var totalDuration: Double {
        Double(text.count) * charInterval
    }
}
```

**Step 4: Run tests**

```bash
swift test
```

Expected: all PASS.

**Step 5: Commit**

```bash
git add GOD/GOD/Models/Tips.swift GOD/Tests/TipsTests.swift
git commit -m "feat: add tips system with shuffle-deck and typewriter"
```

---

### Task 12: SwiftUI — Theme & Colors

**Files:**
- Create: `GOD/GOD/Views/Theme.swift`

**Step 1: Create theme constants**

```swift
// GOD/GOD/Views/Theme.swift
import SwiftUI

enum Theme {
    static let bg = Color(red: 0.102, green: 0.098, blue: 0.090)       // #1a1917
    static let text = Color(red: 0.831, green: 0.812, blue: 0.776)     // #d4cfc6
    static let dim = Color(red: 0.478, green: 0.459, blue: 0.420)      // #7a756b
    static let muted = Color(red: 0.290, green: 0.275, blue: 0.251)    // #4a4640
    static let accent = Color(red: 0.855, green: 0.482, blue: 0.290)   // #da7b4a
    static let green = Color(red: 0.373, green: 0.667, blue: 0.431)    // #5faa6e
    static let red = Color(red: 0.831, green: 0.337, blue: 0.306)      // #d4564e
    static let amber = Color(red: 0.831, green: 0.635, blue: 0.306)    // #d4a24e

    static let mono = Font.custom("JetBrains Mono", size: 13)
    static let monoSmall = Font.custom("JetBrains Mono", size: 11)
    static let monoTiny = Font.custom("JetBrains Mono", size: 10)
    static let monoLarge = Font.custom("JetBrains Mono", size: 18)
    static let monoTitle = Font.custom("JetBrains Mono", size: 24)
}
```

**Step 2: Verify it compiles**

```bash
swift build
```

**Step 3: Commit**

```bash
git add GOD/GOD/Views/Theme.swift
git commit -m "feat: add MOMENT-inspired theme constants"
```

---

### Task 13: SwiftUI — Main Layout

**Files:**
- Modify: `GOD/GOD/ContentView.swift`
- Create: `GOD/GOD/Views/TitleView.swift`
- Create: `GOD/GOD/Views/TransportView.swift`
- Create: `GOD/GOD/Views/LoopBarView.swift`
- Create: `GOD/GOD/Views/PadGridView.swift`
- Create: `GOD/GOD/Views/LayerListView.swift`
- Create: `GOD/GOD/Views/CaptureIndicatorView.swift`
- Create: `GOD/GOD/Views/TipView.swift`
- Create: `GOD/GOD/Views/CommandInputView.swift`

**Step 1: Build all views and wire into ContentView**

```swift
// GOD/GOD/Views/TitleView.swift
import SwiftUI

struct TitleView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        Text("G O D")
            .font(Theme.monoTitle)
            .foregroundColor(Theme.text)
            .opacity(0.8 + 0.2 * sin(phase))
            .onAppear {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    phase = .pi * 2
                }
            }
    }
}
```

```swift
// GOD/GOD/Views/TransportView.swift
import SwiftUI

struct TransportView: View {
    @ObservedObject var engine: GodEngine

    var body: some View {
        HStack(spacing: 16) {
            Text(engine.transport.isPlaying ? "▶" : "■")
                .foregroundColor(engine.transport.isPlaying ? Theme.green : Theme.dim)

            Text("\(engine.transport.bpm) BPM")
                .foregroundColor(Theme.text)

            Text("·")
                .foregroundColor(Theme.muted)

            Text("\(engine.transport.barCount) BARS")
                .foregroundColor(Theme.text)

            Text("·")
                .foregroundColor(Theme.muted)

            Text("♩ \(engine.metronome.isOn ? "ON" : "OFF")")
                .foregroundColor(engine.metronome.isOn ? Theme.accent : Theme.dim)
        }
        .font(Theme.mono)
    }
}
```

```swift
// GOD/GOD/Views/LoopBarView.swift
import SwiftUI

struct LoopBarView: View {
    @ObservedObject var engine: GodEngine

    private var progress: Double {
        guard engine.transport.loopLengthFrames > 0 else { return 0 }
        return Double(engine.transport.position) / Double(engine.transport.loopLengthFrames)
    }

    private var currentBeat: Int {
        let beatLength = engine.metronome.beatLengthFrames(
            bpm: engine.transport.bpm,
            sampleRate: Transport.sampleRate
        )
        guard beatLength > 0 else { return 0 }
        return engine.transport.position / beatLength
    }

    private var totalBeats: Int {
        engine.transport.barCount * 4
    }

    var body: some View {
        VStack(spacing: 4) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.muted.opacity(0.3))
                        .frame(height: 2)

                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * progress, height: 2)
                }
            }
            .frame(height: 2)

            // Beat markers
            HStack(spacing: 0) {
                ForEach(0..<totalBeats, id: \.self) { beat in
                    if beat > 0 { Spacer() }
                    if beat % 4 == 0 {
                        Text("\(beat / 4 + 1)")
                            .foregroundColor(currentBeat == beat ? Theme.accent : Theme.dim)
                    } else {
                        Text("·")
                            .foregroundColor(Theme.muted)
                    }
                }
            }
            .font(Theme.monoSmall)
        }
    }
}
```

```swift
// GOD/GOD/Views/PadGridView.swift
import SwiftUI

struct PadGridView: View {
    @ObservedObject var engine: GodEngine
    @State private var flashStates: [Bool] = Array(repeating: false, count: 8)

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                ForEach(0..<8, id: \.self) { i in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(flashStates[i] ? Theme.accent : Theme.muted.opacity(0.4))
                            .frame(width: 50, height: 40)
                            .overlay(
                                Text("\(i + 1)")
                                    .font(Theme.monoSmall)
                                    .foregroundColor(Theme.dim)
                            )
                        Text(engine.padBank.pads[i].name)
                            .font(Theme.monoTiny)
                            .foregroundColor(Theme.dim)
                            .lineLimit(1)
                            .frame(width: 50)
                    }
                }
            }
        }
    }

    func flash(pad index: Int) {
        flashStates[index] = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            flashStates[index] = false
        }
    }
}
```

```swift
// GOD/GOD/Views/LayerListView.swift
import SwiftUI

struct LayerListView: View {
    @ObservedObject var engine: GodEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(engine.layers.indices, id: \.self) { i in
                let layer = engine.layers[i]
                if !layer.hits.isEmpty || engine.padBank.pads[i].sample != nil {
                    LayerRow(
                        layer: layer,
                        loopLength: engine.transport.loopLengthFrames,
                        position: engine.transport.position
                    )
                }
            }
        }
    }
}

struct LayerRow: View {
    let layer: Layer
    let loopLength: Int
    let position: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("\(layer.index + 1)")
                .foregroundColor(Theme.dim)
                .frame(width: 16, alignment: .trailing)

            Text(layer.name)
                .foregroundColor(layer.isMuted ? Theme.muted : Theme.text)
                .frame(width: 50, alignment: .leading)

            Text(layer.isMuted ? "■" : "▶")
                .foregroundColor(layer.isMuted ? Theme.muted : Theme.green)

            // Hit pattern visualization
            HitPatternView(hits: layer.hits, loopLength: loopLength)
                .opacity(layer.isMuted ? 0.3 : 1.0)
        }
        .font(Theme.monoSmall)
    }
}

struct HitPatternView: View {
    let hits: [Hit]
    let loopLength: Int

    private let resolution = 32 // dots across the display

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<resolution, id: \.self) { slot in
                let slotStart = loopLength * slot / resolution
                let slotEnd = loopLength * (slot + 1) / resolution
                let hasHit = hits.contains { $0.position >= slotStart && $0.position < slotEnd }
                Text(hasHit ? "●" : "·")
                    .foregroundColor(hasHit ? Theme.accent : Theme.muted)
            }
        }
        .font(.system(size: 8, design: .monospaced))
    }
}
```

```swift
// GOD/GOD/Views/CaptureIndicatorView.swift
import SwiftUI

struct CaptureIndicatorView: View {
    @ObservedObject var engine: GodEngine
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(captureColor)
                .frame(width: 8, height: 8)
                .opacity(engine.capture.state == .recording ? (pulse ? 1.0 : 0.4) : 1.0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }

            Text("GOD")
                .font(Theme.mono)
                .foregroundColor(captureColor)

            if engine.capture.state == .armed {
                Text("ARMED")
                    .font(Theme.monoSmall)
                    .foregroundColor(Theme.amber)
            } else if engine.capture.state == .recording {
                Text("REC")
                    .font(Theme.monoSmall)
                    .foregroundColor(Theme.red)
            }
        }
    }

    private var captureColor: Color {
        switch engine.capture.state {
        case .idle: return Theme.dim
        case .armed: return Theme.amber
        case .recording: return Theme.red
        }
    }
}
```

```swift
// GOD/GOD/Views/TipView.swift
import SwiftUI

struct TipView: View {
    @State private var tipDeck = TipDeck()
    @State private var currentTip = ""
    @State private var tipStartTime = Date()
    @State private var elapsed: Double = 0

    private let charInterval = 0.08  // 80ms per character
    private let cycleInterval = 12.0 // 12 seconds per tip
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            let typewriter = TypewriterState(text: currentTip, charInterval: charInterval)
            let visible = typewriter.visibleText(elapsed: elapsed)

            Text("\"\(visible)\"")
                .font(Theme.monoSmall)
                .foregroundColor(Theme.dim)

            if elapsed >= typewriter.totalDuration {
                Text("— claude")
                    .font(Theme.monoTiny)
                    .foregroundColor(Theme.muted)
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

```swift
// GOD/GOD/Views/CommandInputView.swift
import SwiftUI

struct CommandInputView: View {
    @ObservedObject var engine: GodEngine
    @State private var command = ""

    var body: some View {
        HStack(spacing: 4) {
            Text(">")
                .foregroundColor(Theme.dim)
            TextField("", text: $command)
                .textFieldStyle(.plain)
                .foregroundColor(Theme.text)
                .onSubmit {
                    engine.executeCommand(command)
                    command = ""
                }
        }
        .font(Theme.mono)
    }
}
```

**Step 2: Wire everything into ContentView**

```swift
// GOD/GOD/ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var engine = GodEngine()

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 20) {
                TitleView()

                TransportView(engine: engine)

                LoopBarView(engine: engine)
                    .padding(.horizontal)

                PadGridView(engine: engine)

                LayerListView(engine: engine)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                Spacer()

                CaptureIndicatorView(engine: engine)

                TipView()
                    .padding(.horizontal)

                CommandInputView(engine: engine)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .padding()
        }
        .onAppear {
            // Start audio and MIDI managers here
        }
        .onKeyPress(.space) {
            engine.togglePlay()
            return .handled
        }
        .onKeyPress("g") {
            engine.toggleCapture()
            return .handled
        }
        .onKeyPress("m") {
            engine.toggleMetronome()
            return .handled
        }
        .onKeyPress(.upArrow) {
            engine.setBPM(engine.transport.bpm + 1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            engine.setBPM(engine.transport.bpm - 1)
            return .handled
        }
        .onKeyPress(.escape) {
            engine.stop()
            return .handled
        }
        .onKeyPress("1") { engine.toggleMute(layer: 0); return .handled }
        .onKeyPress("2") { engine.toggleMute(layer: 1); return .handled }
        .onKeyPress("3") { engine.toggleMute(layer: 2); return .handled }
        .onKeyPress("4") { engine.toggleMute(layer: 3); return .handled }
        .onKeyPress("5") { engine.toggleMute(layer: 4); return .handled }
        .onKeyPress("6") { engine.toggleMute(layer: 5); return .handled }
        .onKeyPress("7") { engine.toggleMute(layer: 6); return .handled }
        .onKeyPress("8") { engine.toggleMute(layer: 7); return .handled }
    }
}
```

**Step 3: Verify it builds**

```bash
swift build
```

**Step 4: Commit**

```bash
git add GOD/GOD/Views/ GOD/GOD/ContentView.swift
git commit -m "feat: add full SwiftUI view layer with MOMENT-inspired design"
```

---

### Task 14: Wire Audio & MIDI Managers to App Lifecycle

**Files:**
- Modify: `GOD/GOD/ContentView.swift`
- Modify: `GOD/GOD/GODApp.swift`

**Step 1: Wire managers into the app**

Update `GODApp.swift`:

```swift
// GOD/GOD/GODApp.swift
import SwiftUI

@main
struct GODApp: App {
    @StateObject private var engine = GodEngine()

    var body: some Scene {
        WindowGroup {
            ContentView(engine: engine)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 700)
    }
}
```

Update `ContentView` to accept engine as parameter instead of creating it:

```swift
// ContentView changes:
// Replace: @StateObject private var engine = GodEngine()
// With:    @ObservedObject var engine: GodEngine
```

Add AudioManager and MIDIManager initialization in `ContentView.onAppear`:

```swift
.onAppear {
    let audio = AudioManager(engine: engine)
    try? audio.start()
    let midi = MIDIManager(engine: engine)
    midi.start()
}
```

**Step 2: Add entitlements for audio/MIDI**

Create `GOD/GOD/GOD.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
```

**Step 3: Verify it builds**

```bash
swift build
```

**Step 4: Commit**

```bash
git add GOD/GOD/
git commit -m "feat: wire AudioManager and MIDIManager to app lifecycle"
```

---

### Task 15: Sample Setup View

**Files:**
- Create: `GOD/GOD/Views/SetupView.swift`
- Modify: `GOD/GOD/ContentView.swift`

**Step 1: Create sample setup view**

```swift
// GOD/GOD/Views/SetupView.swift
import SwiftUI
import UniformTypeIdentifiers

struct SetupView: View {
    @ObservedObject var engine: GodEngine
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("SET UP PADS")
                    .font(Theme.monoLarge)
                    .foregroundColor(Theme.text)

                ForEach(0..<8, id: \.self) { i in
                    HStack {
                        Text("PAD \(i + 1)")
                            .font(Theme.mono)
                            .foregroundColor(Theme.dim)
                            .frame(width: 60, alignment: .leading)

                        Text(engine.padBank.pads[i].sample?.name ?? "—")
                            .font(Theme.mono)
                            .foregroundColor(Theme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("LOAD") {
                            loadSample(forPad: i)
                        }
                        .font(Theme.monoSmall)
                        .foregroundColor(Theme.accent)
                        .buttonStyle(.plain)

                        if engine.padBank.pads[i].sample != nil {
                            Button("×") {
                                engine.padBank.pads[i].sample = nil
                                engine.padBank.pads[i].samplePath = nil
                                engine.padBank.pads[i].name = "PAD \(i + 1)"
                            }
                            .font(Theme.mono)
                            .foregroundColor(Theme.red)
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()

                Button("DONE") {
                    try? engine.padBank.save()
                    isPresented = false
                }
                .font(Theme.mono)
                .foregroundColor(Theme.accent)
                .buttonStyle(.plain)
                .padding()
            }
            .padding()
        }
    }

    private func loadSample(forPad index: Int) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType.wav, UTType.mp3, UTType.aiff,
            UTType(filenameExtension: "flac") ?? .audio
        ]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            if let sample = try? Sample.load(from: url) {
                engine.padBank.assign(sample: sample, toPad: index)
                engine.padBank.pads[index].samplePath = url.path
                engine.layers[index].name = sample.name.uppercased()
            }
        }
    }
}
```

**Step 2: Add setup toggle to ContentView**

Add to ContentView:
```swift
@State private var showSetup = false

// Add button near title:
Button("SETUP") { showSetup = true }
    .font(Theme.monoSmall)
    .foregroundColor(Theme.dim)
    .buttonStyle(.plain)
    .sheet(isPresented: $showSetup) {
        SetupView(engine: engine, isPresented: $showSetup)
            .frame(width: 500, height: 500)
    }
```

**Step 3: Verify it builds**

```bash
swift build
```

**Step 4: Commit**

```bash
git add GOD/GOD/Views/SetupView.swift GOD/GOD/ContentView.swift
git commit -m "feat: add sample setup view with file picker"
```

---

### Task 16: Integration Testing & Manual Verification

**Files:**
- No new files — manual testing

**Step 1: Build and run the app**

```bash
cd ~/god/GOD
swift build
swift run GOD
```

**Step 2: Manual verification checklist**

- [ ] Window appears with dark theme, GOD title, transport display
- [ ] Space toggles play/stop, transport state updates
- [ ] Up/down arrows change BPM
- [ ] M toggles metronome indicator
- [ ] G toggles GOD capture indicator (idle → armed → recording)
- [ ] Setup view opens, can load WAV files to pads
- [ ] MiniLab 3 pads trigger samples and record hits into layers
- [ ] Layer visualization shows hit positions
- [ ] 1-8 keys toggle mute on layers
- [ ] Command input accepts and executes commands
- [ ] Tips cycle with typewriter effect
- [ ] Loop bar animates during playback

**Step 3: Fix any issues found**

Address bugs as discovered during manual testing.

**Step 4: Commit fixes**

```bash
git add -A
git commit -m "fix: integration testing fixes"
```

---

### Task 17: Update CLAUDE.md

**Files:**
- Modify: `~/god/CLAUDE.md`

**Step 1: Update CLAUDE.md to reflect v2**

```markdown
# GOD — Genesis On Disk

Native macOS loop-stacking instrument.

## What This Is
A SwiftUI app for live loop-stacking driven by an Arturia MiniLab 3. Not a DAW. A performance instrument. Play pads, stack layers, capture output.

## Core Workflow
- Set tempo (whole numbers) and bar length (1, 2, or 4 bars)
- Play MiniLab 3 pads — samples trigger and record into their layer
- Each pad = one layer. Stack layers, mute/unmute/clear to shape the beat
- **GOD capture**: arms, then records master output on next loop boundary
- Keyboard shortcuts for fast control during performance

## Tech Stack
- Swift, SwiftUI
- CoreAudio (AVAudioEngine) for audio
- CoreMIDI for MIDI input
- macOS 14+

## Project Structure
- `GOD/GOD/Models/` — Transport, Sample, Voice, Layer, Pad, Metronome, GodCapture, Tips
- `GOD/GOD/Engine/` — GodEngine, AudioManager, MIDIManager
- `GOD/GOD/Views/` — SwiftUI views (Theme, Transport, LoopBar, PadGrid, LayerList, Tips, etc.)
- `GOD/Tests/` — Swift Testing unit tests

## Principles
- Light and fast
- Performance-first — you play, it records
- MOMENT-inspired aesthetic: dark, monospace, animated, Claude tips
- No bloat, no DAW features you won't use
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for GOD v2 native app"
```

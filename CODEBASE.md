# GOD Codebase Reference

> Auto-generated codebase summary. Read this instead of individual source files.
> Only read source files when you need to make changes to them.

## Package

- `GOD/Package.swift` — Swift Package Manager, swift-tools-version 5.9, macOS 14+
- Executable target `GOD` (path: `GOD/`), test target `GODTests` (path: `Tests/`)
- No external dependencies

## Architecture Overview

```
GODApp (@main)
  ├── GodEngine (ObservableObject) — central state, audio processing
  │     ├── Transport (struct) — BPM, bar count, position, loop length
  │     ├── PadBank (struct) — 8 pads, MIDI note mapping, Splice loading, config persistence
  │     ├── Layer[8] (struct) — per-pad hit recording, mute, volume, pan, HP/LP filters, cut
  │     ├── Voice[] (struct) — active audio voices with per-voice biquad filter state
  │     ├── Metronome (struct) — click generation
  │     ├── GodCapture (struct) — idle→armed→recording state machine, WAV export
  │     └── MIDIRingBuffer — lock-free SPSC ring buffer for MIDI→audio thread
  ├── AudioManager — AVAudioEngine + AVAudioSourceNode, calls engine.processBlock()
  ├── MIDIManager (ObservableObject) — CoreMIDI input, auto-connects sources, writes to ring buffer
  └── EngineEventInterpreter (ObservableObject) — terminal log + pad intensity visuals
```

## Models (GOD/GOD/Models/)

### Transport.swift
```swift
struct Transport {
    static let sampleRate: Double = 44100.0
    var bpm: Int = 120          // clamped 1-999
    var barCount: Int = 4       // valid: 1, 2, 4
    var position: Int = 0       // current frame position
    var isPlaying: Bool = false
    var loopLengthFrames: Int   // computed: barCount * 4 beats * (60/bpm) * sampleRate
    mutating func advance(frames:) -> Bool  // returns true on loop wrap
    mutating func reset()
}
```

### Sample.swift
```swift
enum SampleError: Error { case conversionFailed }
struct Sample {
    let name: String
    let left: [Float], right: [Float]
    let sampleRate: Double
    var frameCount: Int         // left.count
    var durationMs: Double
    static func load(from url: URL) throws -> Sample  // AVAudioFile → convert to 44100Hz stereo
}
```

### Pad.swift
```swift
struct Pad {
    let index: Int, midiNote: Int
    var name: String, sample: Sample?, samplePath: String?
    var isOneShot: Bool = true, cut: Bool = false
}
struct PadAssignment: Codable { let path: String, name: String; var cut: Bool? }
struct PadConfig: Codable { var assignments: [String: PadAssignment] }
struct PadBank {
    static let baseNote = 36, padCount = 8
    static let spliceFolderNames = ["kicks","snares","hats","perc","bass","keys","vox","fx"]
    static let spliceBasePath: URL   // ~/Splice/sounds/
    static let audioExtensions: Set<String>  // wav, aif, aiff, mp3, m4a, flac, ogg
    var pads: [Pad]              // 8 pads, MIDI notes 36-43
    func padIndex(forNote:) -> Int?
    mutating func assign(sample:toPad:)
    var config: PadConfig
    static let configURL: URL    // ~/.god/pads.json
    func save() throws
    mutating func loadConfig() throws
    mutating func loadFromSpliceFolders()
}
```

### Layer.swift
```swift
struct Hit { let position: Int, velocity: Int }  // frame offset + MIDI velocity
struct Layer {
    let index: Int; var name: String
    var hits: [Hit], isMuted: Bool, volume: Float = 1.0
    var pan: Float = 0.5        // 0=L, 0.5=C, 1=R
    var hpCutoff: Float = 20.0  // Hz
    var lpCutoff: Float = 20000.0
    var cut: Bool = false
    mutating func addHit(at:velocity:)
    func hits(inRange:) -> [Hit]
    mutating func clear()       // saves to previousHits for undo
    mutating func undo()
    var canUndo: Bool
}
```

### Voice.swift
```swift
struct Voice {
    let sample: Sample; let velocity: Float
    var padIndex: Int = -1, position: Int = 0
    var hpStateL/R, lpStateL/R: BiquadState  // per-voice filter state
    mutating func fill(intoLeft:right:count:pan:hpCoeffs:lpCoeffs:) -> (finished: Bool, peak: Float)
    // Mixes into stereo buffers with equal-power pan + biquad filtering
}
```

### Biquad.swift
```swift
struct BiquadState { var z1: Float, z2: Float }
struct BiquadCoefficients {
    var b0, b1, b2, a1, a2: Float
    static let bypass: BiquadCoefficients
    static func lowPass(cutoff:sampleRate:) -> BiquadCoefficients   // 12dB/oct Butterworth
    static func highPass(cutoff:sampleRate:) -> BiquadCoefficients
}
func biquadProcessSample(_:coeffs:state:) -> Float  // Direct Form II Transposed
func ccToFrequency(_ cc: Int) -> Float  // 0-127 → 20Hz-20kHz exponential
```

### Metronome.swift
```swift
struct Metronome {
    var isOn: Bool = true, volume: Float = 0.5
    static func beatLengthFramesStatic(bpm:sampleRate:) -> Int
    static func generateClick(isDownbeat:sampleRate:) -> Sample  // 20ms sine burst
}
```

### GodCapture.swift
```swift
struct GodCapture {
    enum State { case idle, armed, recording }
    var state: State = .idle
    mutating func toggle()          // idle→armed, armed→idle, recording→writeAndReset+idle
    mutating func onLoopBoundary()  // armed→recording (clears buffers)
    mutating func append(left:right:)
    // Writes stereo WAV to ~/recordings/GOD_YYYYMMDD_HHMMSS.wav
}
```

## Engine (GOD/GOD/Engine/)

### GodEngine.swift — Central hub, ~380 lines
- `@Published` state: transport, layers[8], padBank, metronome, capture, channelSignalLevels, channelTriggered, masterLevel, masterVolume, detectedBPMs, activePadIndex
- `AudioState` struct (defined above class): groups all audio-thread-only state (position, isPlaying, bpm, barCount, metronomeOn, metronomeVolume, layers, captureState, capture, activePadIndex, toggleMode, pendingMutes, loopLengthFrames computed property)
- Single `private var audio = AudioState()` replaces individual `audio*` fields
- Key methods: togglePlay(), stop(), setBPM(), setBarCount(), cycleBarCount(), setMasterVolume(), toggleMute(), toggleCut(), clearLayer(), undoLastClear(), toggleCapture(), toggleMetronome(), detectBPM()
- `processBlock(frameCount:) -> (left: [Float], right: [Float])` — THE audio render callback:
  1. Scans audioLayers for loop-replayed hits
  2. Drains MIDIRingBuffer for live hits (after loop scan to avoid double-trigger)
  3. Generates metronome clicks on beat boundaries
  4. Advances position, handles loop wrap
  5. Capture recording
  6. Mixes all voices with per-layer biquad filters + pan
  7. Applies master volume
  8. Throttled UI sync (~30fps) via DispatchQueue.main.async
- CC routing: CC14=volume, CC15=pan, CC16=HP cutoff, CC17=LP cutoff (applied to active pad)

### AudioManager.swift — 59 lines
- Wraps AVAudioEngine + AVAudioSourceNode
- Calls godEngine.processBlock() in audio render callback
- Format: stereo 44100Hz

### MIDIManager.swift — 178 lines
- CoreMIDI client with auto-connect/disconnect
- Parses MIDI 1.0 Channel Voice messages (type 0x2)
- Writes noteOn/noteOff/CC events to MIDIRingBuffer
- Prioritizes MiniLab 3 for display name

### MIDIRingBuffer.swift — 39 lines
- Lock-free SPSC ring buffer (256 slots)
- Uses OSMemoryBarrier() for ARM64 memory ordering
- `enum MIDIEvent { case noteOn(note:velocity:), noteOff(note:), cc(number:value:) }`

### EngineEventInterpreter.swift — 210 lines
- Terminal log with TerminalLine entries (text, kind, timestamp)
- `LineKind` enum: system, transport, hit, state, capture, browse
- Tracks pad intensities for visual columns (decay animation)
- processHits() — logs hit events, updates intensities
- processStateDiff() — diffs transport/mute/CC/capture changes, emits log lines
- onLoopBoundary() — emits per-layer summary
- tickVisuals() — decays pad intensities (sustain vs short decay)
- Format helpers: formatFrequency(), formatPan(), formatDuration()

### BPMDetector.swift — 80 lines
- Energy-based onset detection using Accelerate/vDSP
- Window 1024, hop 512, onset peaks → inter-onset intervals → histogram → best BPM
- Normalizes to 70-180 BPM range

## Views (GOD/GOD/Views/)

### Theme.swift
- Colors: bg (#1a1917), blue (#6283e2), ice (#64beff), orange (#da7b4a), green, red, amber, subtle, charcoal, canvasBg (#131210)
- Fonts: mono (16pt), monoSmall (14), monoTiny (12), monoLarge (22), monoTitle (28 bold)

### ContentView.swift — 447 lines
- Root view with KeyCaptureView (NSView) for keyboard input
- Layout: HStack[CanvasView + CCPanelView] → LoopProgressBar → PadStripView → Hotkeys strip
- `EditMode` enum (.normal, .bpm, .browse) replaces boolean state flags
- Key handling split into mode-dispatched methods: handleKey → handleShiftPad, handleBPMKey, handleBrowseKey, handleNormalKey
- Keys: SPC=play, G=capture, A/D=pad nav, Shift+1-8=pad jump, Q=cool(mute), E=hot(unmute), M=metro, B=bpm, []=bars, V=master vol mode, 0-9=volume, Z=undo, C=clear, X=cut, T=browse, ESC=stop, ?=help

### CanvasView.swift — 322 lines
- Three layers: PadVisualsLayer (orange gradient columns), GodTitleLayer (animated pixel GOD letters + ambient swirl), TerminalTextLayer (scrolling log)
- GodTitleLayer: pixel bitmaps for G/O/D letters, animated drift + pulse, three visual modes (idle=ice, playing=orange, godMode=orange+red)
- TerminalTextLayer: scrolling log with line-kind coloring, blinking cursor, fade-in opacity

### PadStripView.swift — 593 lines
- PadStripView: HStack of 8 PadCell views
- PadCell: sample name (MarqueeText), folder label, signal meter, hot/cold/active styling with glow/frost
- MarqueeText: auto-scrolling text for long names using TimelineView
- LoopProgressBar: thin horizontal progress bar
- CCPanelView (right panel, 190px): master volume display, pad inspector (sample info, params, cut badge), sample browser
- SampleBrowserView: lists files from Splice folder, W/S navigation, tap to load, file picker fallback
- Helper views: InspectorSectionHeader, InspectorRow, CutBadge

### TransportView.swift — 112 lines
- Horizontal bar: play state, BPM, bar count, metronome, beat counter, capture status, master volume, loop progress

### KeyReferenceOverlay.swift — 58 lines
- Help overlay listing all keyboard shortcuts

## App Entry (GODApp.swift) — 164 lines
- @main struct, creates GodEngine + EngineEventInterpreter
- startManagers(): loads pad config → Splice folders → wires interpreter → starts AudioManager → starts MIDIManager
- Programmatic dock icon (pixel-art GOD in orange on dark bg)
- Window: hiddenTitleBar, 1000x700 default

## Key Patterns
- **Dual-state architecture**: GodEngine has @Published UI state AND audio-thread mirror state. Audio thread never touches @Published. UI sync happens via DispatchQueue.main.async at ~30fps.
- **Lock-free MIDI**: MIDIManager → MIDIRingBuffer (SPSC, OSMemoryBarrier) → drained in processBlock()
- **Loop recording**: hits recorded with frame position, replayed on each loop cycle by scanning layer.hits(inRange:)
- **Per-layer effects**: volume, pan, HP/LP biquad filters applied per-voice in Voice.fill()
- **Splice integration**: auto-loads from ~/Splice/sounds/{kicks,snares,hats,perc,bass,keys,vox,fx}/
- **Pad config**: persisted to ~/.god/pads.json

## Test Files (GOD/Tests/)
12 test files using Swift Testing framework (@Test, #expect):
- TransportTests, LayerTests, PadTests, VoiceTests, MetronomeTests
- GodEngineTests, GodCaptureTests, BiquadTests
- MIDITests, MIDIRingBufferTests, EngineEventInterpreterTests
- BPMDetectorTests, SpliceLoadingTests

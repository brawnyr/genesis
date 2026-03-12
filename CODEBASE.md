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
  │     ├── Layer[8] (struct) — per-pad hit recording, mute, volume, pan, HP/LP filters, tcps
  │     ├── Voice[] (struct) — active audio voices with per-voice biquad filter state
  │     ├── Metronome (struct) — click generation
  │     ├── GodCapture (struct) — idle→armed→recording state machine, WAV export
  │     └── MIDIRingBuffer — lock-free SPSC ring buffer for MIDI→audio thread
  ├── AudioManager — AVAudioEngine + AVAudioSourceNode, calls engine.processBlock()
  ├── MIDIManager — CoreMIDI input, auto-connects sources, writes to ring buffer
  └── EngineEventInterpreter (ObservableObject) — terminal log + pad intensity visuals
```

## Models (GOD/GOD/Models/)

### Transport.swift
```swift
struct Transport {
    static let sampleRate: Double = 44100.0
    static let beatsPerBar = 4
    var bpm: Int = 120          // clamped 1-999
    var barCount: Int = 4       // valid: 1, 2, 4
    var position: Int = 0       // current frame position
    var isPlaying: Bool = false
    var loopLengthFrames: Int   // computed: barCount * beatsPerBar * (60/bpm) * sampleRate
    var currentBeat: Int        // computed: 1-based beat position in loop
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
    var isOneShot: Bool = true, tcps: Bool = true
}
struct PadAssignment: Codable { let path: String, name: String; var tcps: Bool? }
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
    static let hpBypassFrequency: Float = 20.0
    static let lpBypassFrequency: Float = 20000.0
    var hpCutoff: Float = Layer.hpBypassFrequency
    var lpCutoff: Float = Layer.lpBypassFrequency
    var tcps: Bool = true         // "this cuts previous sound" — kills previous voice on same pad
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
func ccToFrequency(_ cc: Int) -> Float  // 0-127 → 20Hz-20kHz exponential (input clamped)
```

### Metronome.swift
```swift
struct Metronome {
    var isOn: Bool = true, volume: Float = 0.5
    // Named constants: clickDuration, downbeatFreq, beatFreq, downbeatAmplitude, beatAmplitude, clickDecayRate
    static func beatLengthFramesStatic(bpm:sampleRate:) -> Int
    static func click(isDownbeat:) -> Sample  // cached 20ms sine burst, generated once
}
```

### GodCapture.swift
```swift
struct GodCapture {
    enum State { case idle, armed, recording }
    var state: State = .idle
    private static let filenameDateFormatter: DateFormatter  // cached static lazy
    mutating func toggle()          // idle→armed, armed→idle, recording→writeAndReset+idle
    mutating func onLoopBoundary()  // armed→recording (clears buffers)
    mutating func append(left:right:)
    // Writes stereo WAV to ~/recordings/GOD_YYYYMMDD_HHMMSS.wav
}
```

## Engine (GOD/GOD/Engine/)

### GodEngine.swift — State & control, ~298 lines
- `@Published` state: transport, layers[PadBank.padCount], padBank, metronome, capture, channelSignalLevels, channelTriggered, masterLevel, masterVolume (persisted), detectedBPMs, activePadIndex (syncs audio→main), velocityMode
- `AudioState` struct (audio-thread-only): groups position, isPlaying, bpm, barCount, metronomeOn, metronomeVolume, layers, captureState, capture, activePadIndex, toggleMode, pendingMutes, loopLengthFrames (computed)
- `ToggleMode` enum (.instant, .nextLoop), `VelocityMode` enum (.pressure, .full)
- Key methods: togglePlay(), stop(), setBPM(), setBarCount(), cycleBarCount(), setMasterVolume(), toggleMute() (kills voices on mute), toggleTcps(), clearLayer(), undoLastClear(), toggleCapture(), toggleMetronome(), detectBPM(), killAllVoices(), cycleVelocityMode(), loadSample()
- Master volume persistence: loadMasterVolume()/saveMasterVolume() via ~/.god/master.txt

### GodEngine+ProcessBlock.swift — Audio render callback, ~298 lines
- Extension on GodEngine with processBlock() and audio-thread helpers
- handlePadHit(), handleNoteOff(), handleCC(), updateCachedCoefficients()
- `processBlock(frameCount:intoLeft:intoRight:)` — THE audio render callback (writes directly to audio buffer pointers, locked with os_unfair_lock):
  1. Scans audioLayers for loop-replayed hits
  2. Drains MIDIRingBuffer for live hits (after loop scan to avoid double-trigger)
  3. Generates metronome clicks on beat boundaries
  4. Advances position, handles loop wrap + pending mute application
  5. Capture recording
  6. Calls VoiceMixer.mix() for voice rendering
  7. Applies master volume
  8. Throttled UI sync (~30fps) via DispatchQueue.main.async
- CC routing: CC82=master volume, CC74=pad volume, CC71=pan, CC76=HP cutoff, CC77=LP cutoff, CC114=browse encoder

### VoiceMixer.swift — Stateless voice mixer, ~33 lines
- `enum VoiceMixer` with static `mix()` method
- Pure DSP: renders voices with per-layer biquad filters + pan + volume
- Returns per-pad peak levels, removes finished voices via compactMap

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
- Terminal log with TerminalLine entries (text, kind, timestamp); cached `timeFormatter` static DateFormatter
- `LineKind` enum: system, transport, hit, state, capture, browse
- Tracks pad intensities for visual columns (decay animation)
- Named decay constants: `shortDecay`, `sustainDecay`, `sustainMinIntensity`, `intensityCutoff`
- processHits() — logs hit events, updates intensities
- processStateDiff() — diffs transport/mute/CC/capture changes, emits log lines
- onLoopBoundary() — emits per-layer summary
- tickVisuals() — decays pad intensities (sustain vs short decay)
- Format helpers: formatFrequency(), formatPan(), formatDuration()

### BPMDetector.swift — 80 lines
- Energy-based onset detection using Accelerate/vDSP
- Named constants: windowSize, hopSize, onsetThresholdMultiplier, minIntervalSec, maxIntervalSec, histogramBinSec, minBPM, maxBPM
- Normalizes to 70-180 BPM range

## Views (GOD/GOD/Views/)

### Theme.swift
- Colors: bg (#1a1917), blue (#6283e2), ice (#64beff), orange (#da7b4a), green, red, amber, subtle, charcoal, canvasBg (#131210)
- Fonts: mono (16pt), monoSmall (14), monoTiny (12), monoLarge (22), monoTitle (28 bold)

### ContentView.swift — ~129 lines
- Root view with KeyCaptureView (NSView) for keyboard input
- Layout: HStack[CanvasView + CCPanelView] → LoopProgressBar → PadStripView → Hotkeys strip
- `EditMode` enum (.normal, .bpm, .browse)
- KeyLabel helper view for hotkey strip

### ContentView+KeyHandlers.swift — ~292 lines
- Extension on ContentView with all keyboard dispatch logic
- Key enum (virtual key codes), bpmPresets array
- Mode-dispatched: handleKey → handleBPMKey, handleBrowseKey, handleNormalKey
- Keys: SPC=play, G=capture, A/D=pad nav, Q=cool(mute), E=hot(unmute), M=metro, B=bpm, []=bars, F=kill all voices, P=velocity mode, 0-9=pad volume, Z=undo, C=clear, X=tcps toggle, N=toggle mode, T=browse, ESC=stop, ?=help

### CanvasView.swift — ~34 lines
- Composes three layers: PadVisualsLayer, GodTitleLayer, TerminalTextLayer

### GodTitleLayer.swift — ~312 lines
- GeoShapeKind enum, GeoShape struct for generative geometric field
- Canvas-based rendering: triangles, hexagons, lines, angular spirals, fragments
- CRT jitter, rotation, fade-in/out, mirror copies
- Three visual modes: idle (ice), playing (orange), godMode (orange+red)
- Master volume ring (64px circle), transport info display

### PadVisualsLayer.swift — ~35 lines
- Orange gradient columns driven by pad intensity values

### TerminalTextLayer.swift — ~67 lines
- Scrolling terminal log with blinking cursor
- Line-kind color coding: system, transport, hit, state, capture, browse

### PadStripView.swift — ~53 lines
- PadStripView: HStack of PadCell views
- LoopProgressBar: thin horizontal progress bar

### PadCell.swift — ~107 lines
- Single pad visual cell with sample name (MarqueeText), folder label, signal meter
- Uses PadCellOverlay modifier

### PadCellOverlay.swift — ~68 lines
- ViewModifier with glow strokes: hot/cold/pending visual states, breathing animation

### MarqueeText.swift — ~70 lines
- Auto-scrolling text for long names using TimelineView

### CCPanelView.swift — ~207 lines
- Right-side inspector panel (260px): sample info, params (vol/pan/HP/LP), mode badges
- Helper views: InspectorSectionHeader, InspectorRow, TcpsBadge, ToggleModeBadge

### SampleBrowserView.swift — ~137 lines
- File browser overlay with W/S navigation, file picker fallback

### KeyReferenceOverlay.swift — ~120 lines
- `KeyAction` enum (CaseIterable): all keyboard shortcuts with key/action string pairs (includes velocityMode, tcpsMode)
- Help overlay iterates KeyAction.allCases for display

## App Entry (GODApp.swift) — ~186 lines
- @main struct, creates GodEngine + EngineEventInterpreter
- Crash logging: installCrashHandlers() — NSSetUncaughtExceptionHandler + signal handlers, writes to ~/.god/crash.log
- startManagers(): loads pad config → Splice folders → wires interpreter → starts AudioManager → starts MIDIManager
- Programmatic dock icon ("GENESIS" text in orange monospace on dark bg)
- Window: hiddenTitleBar, 1000x700 default

## Key Patterns
- **Dual-state architecture**: GodEngine has @Published UI state AND audio-thread mirror state. Audio thread never touches @Published. UI sync happens via DispatchQueue.main.async at ~30fps. Main-thread mutations to audio state are protected by os_unfair_lock.
- **Lock-free MIDI**: MIDIManager → MIDIRingBuffer (SPSC, OSMemoryBarrier) → drained in processBlock()
- **Loop recording**: hits recorded with frame position, replayed on each loop cycle by scanning layer.hits(inRange:)
- **Per-layer effects**: volume, pan, HP/LP biquad filters applied per-voice in Voice.fill()
- **Splice integration**: auto-loads from ~/Splice/sounds/{kicks,snares,hats,perc,bass,keys,vox,fx}/
- **Pad config**: persisted to ~/.god/pads.json
- **Master volume**: persisted to ~/.god/master.txt, loaded on init
- **TCPS (This Cuts Previous Sound)**: ON by default, kills previous voice on same pad when re-triggered
- **Error logging**: Sample/config operations use os.Logger (Pad.swift) or interpreter terminal (ContentView) instead of silent try?

## Test Files (GOD/Tests/)
13 test files using Swift Testing framework (@Test, #expect), 91 tests:
- TransportTests, LayerTests, PadTests, VoiceTests, MetronomeTests
- GodEngineTests, GodCaptureTests, BiquadTests
- MIDITests, MIDIRingBufferTests, EngineEventInterpreterTests
- BPMDetectorTests, SpliceLoadingTests
- All 91 tests pass

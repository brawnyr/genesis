import SwiftUI
import AppKit

// MARK: - Key capture NSView

class KeyCaptureView: NSView {
    var onKeyDown: ((UInt16, String?, NSEvent.ModifierFlags) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool { true }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event.keyCode, event.characters, event.modifierFlags)
    }
}

struct KeyCaptureRepresentable: NSViewRepresentable {
    let onKeyDown: (UInt16, String?, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.onKeyDown = onKeyDown
    }
}

// MARK: - Content view

struct ContentView: View {
    @ObservedObject var engine: GodEngine
    @ObservedObject var interpreter: EngineEventInterpreter
    @State private var showKeyReference = false
    @State private var masterVolumeMode = false
    @State private var browsingPad = false
    @State private var browserIndex: Int = 0
    @State private var bpmMode = false
    @State private var bpmInput = ""
    @State private var bpmPresetIndex = 0

    // BPM presets covering all moods
    private static let bpmPresets: [(bpm: Int, mood: String)] = [
        (60,  "ambient"),
        (70,  "downtempo"),
        (80,  "chill"),
        (85,  "lofi"),
        (90,  "r&b"),
        (95,  "boom bap"),
        (100, "hip hop"),
        (110, "deep house"),
        (115, "afrobeats"),
        (120, "house"),
        (125, "uk garage"),
        (128, "techno"),
        (130, "trance"),
        (135, "jersey club"),
        (140, "dubstep"),
        (150, "footwork"),
        (160, "dnb"),
        (170, "jungle"),
        (174, "liquid dnb"),
    ]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            KeyCaptureRepresentable { keyCode, chars, modifiers in
                handleKey(keyCode: keyCode, chars: chars, modifiers: modifiers)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    CanvasView(engine: engine, interpreter: interpreter)
                    CCPanelView(
                        engine: engine,
                        masterVolumeMode: masterVolumeMode,
                        browsingPad: $browsingPad,
                        browserIndex: $browserIndex
                    )
                }

                // Loop progress bar (above pads)
                LoopProgressBar(engine: engine)

                PadStripView(engine: engine, interpreter: interpreter)

                // Hotkeys strip
                HStack(spacing: 12) {
                    KeyLabel(key: "SPC", action: "play")
                    KeyLabel(key: "G", action: "god")
                    KeyLabel(key: "A/D", action: "pad ←→")
                    KeyLabel(key: "⇧1-8", action: "pad jump")
                    KeyLabel(key: "Q", action: "cool")
                    KeyLabel(key: "E", action: "hot")
                    KeyLabel(key: "M", action: "metro")
                    KeyLabel(key: "B", action: "bpm")
                    KeyLabel(key: "[]", action: "bars")
                    KeyLabel(key: "V", action: masterVolumeMode ? "master focused" : "master unfocused")
                    KeyLabel(key: "0-9", action: "vol")
                    KeyLabel(key: "Z", action: "undo")
                    KeyLabel(key: "C", action: "clear")
                    KeyLabel(key: "T", action: "browse")
                    KeyLabel(key: "ESC", action: "stop")
                    KeyLabel(key: "?", action: "help")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color(red: 0.086, green: 0.082, blue: 0.075))
            }

            if showKeyReference {
                KeyReferenceOverlay(isVisible: $showKeyReference)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    // macOS virtual key codes
    private enum Key {
        static let space: UInt16 = 49
        static let a: UInt16 = 0
        static let d: UInt16 = 2
        static let w: UInt16 = 13
        static let s: UInt16 = 1
        static let q: UInt16 = 12
        static let e: UInt16 = 14
        static let c: UInt16 = 8
        static let g: UInt16 = 5
        static let m: UInt16 = 46
        static let t: UInt16 = 17
        static let v: UInt16 = 9
        static let b: UInt16 = 11
        static let z: UInt16 = 6
        static let returnKey: UInt16 = 36
        static let upArrow: UInt16 = 126
        static let downArrow: UInt16 = 125
        static let escape: UInt16 = 53
        static let leftBracket: UInt16 = 33
        static let rightBracket: UInt16 = 30
    }

    private func padName(_ index: Int) -> String {
        engine.padBank.pads[index].sample?.name.lowercased() ?? PadBank.spliceFolderNames[index]
    }

    private func loadBrowserSample() {
        let padIndex = engine.activePadIndex
        let folderName = PadBank.spliceFolderNames[padIndex]
        let folderURL = PadBank.spliceBasePath.appendingPathComponent(folderName)
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            .filter { PadBank.audioExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }) ?? []
        guard browserIndex < files.count else { return }
        let url = files[browserIndex]
        if let sample = try? Sample.load(from: url) {
            engine.padBank.assign(sample: sample, toPad: padIndex)
            engine.padBank.pads[padIndex].samplePath = url.path
            engine.layers[padIndex].name = sample.name.uppercased()
            engine.syncCutToPadBank()
            try? engine.padBank.save()
            interpreter.appendLine("sample loaded → \(sample.name.lowercased()) on \(folderName)", kind: .browse)
        }
    }

    private func browserFileName() -> String? {
        let padIndex = engine.activePadIndex
        let folderName = PadBank.spliceFolderNames[padIndex]
        let folderURL = PadBank.spliceBasePath.appendingPathComponent(folderName)
        let files = (try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            .filter { PadBank.audioExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }) ?? []
        guard browserIndex >= 0, browserIndex < files.count else { return nil }
        return files[browserIndex].deletingPathExtension().lastPathComponent.lowercased()
    }

    private func handleKey(keyCode: UInt16, chars: String?, modifiers: NSEvent.ModifierFlags) {
        let shift = modifiers.contains(.shift)

        // Shift+1-8: jump directly to pad
        if shift, let c = chars?.first {
            // Shift+number row produces !@#$%^&* on US keyboard
            let shiftDigitMap: [Character: Int] = [
                "!": 0, "@": 1, "#": 2, "$": 3,
                "%": 4, "^": 5, "&": 6, "*": 7
            ]
            if let padIndex = shiftDigitMap[c] {
                engine.activePadIndex = padIndex
                interpreter.appendLine("pad \(padIndex + 1) → \(padName(padIndex))", kind: .state)
                return
            }
        }

        // BPM mode: W/S scroll presets, type digits for custom, ⏎ confirm, ESC cancel
        if bpmMode {
            let presets = Self.bpmPresets
            // W/S scroll through presets
            if keyCode == Key.w {
                bpmPresetIndex = max(0, bpmPresetIndex - 1)
                bpmInput = ""
                let p = presets[bpmPresetIndex]
                engine.setBPM(p.bpm)
                interpreter.appendLine("bpm → \(p.bpm) \(p.mood)", kind: .transport)
                return
            }
            if keyCode == Key.s {
                bpmPresetIndex = min(presets.count - 1, bpmPresetIndex + 1)
                bpmInput = ""
                let p = presets[bpmPresetIndex]
                engine.setBPM(p.bpm)
                interpreter.appendLine("bpm → \(p.bpm) \(p.mood)", kind: .transport)
                return
            }
            // Type digits for custom BPM
            if let c = chars?.first, c >= "0" && c <= "9" {
                bpmInput.append(c)
                interpreter.appendLine("bpm → \(bpmInput)_", kind: .transport)
                return
            }
            switch keyCode {
            case Key.returnKey:
                if let bpm = Int(bpmInput), bpm > 0 {
                    engine.setBPM(bpm)
                    interpreter.appendLine("bpm set → \(bpm)", kind: .transport)
                }
                bpmMode = false
                bpmInput = ""
                return
            case Key.escape, Key.b:
                bpmMode = false
                bpmInput = ""
                interpreter.appendLine("bpm closed", kind: .transport)
                return
            default:
                return
            }
        }

        // When browsing: W/S navigate + auto-load, T/ESC/⏎ closes
        if browsingPad {
            switch keyCode {
            case Key.w:
                browserIndex = max(0, browserIndex - 1)
                loadBrowserSample()
                if let name = browserFileName() {
                    interpreter.appendLine("browse → \(name)", kind: .browse)
                }
                return
            case Key.s:
                browserIndex += 1 // clamped in the view
                loadBrowserSample()
                if let name = browserFileName() {
                    interpreter.appendLine("browse → \(name)", kind: .browse)
                }
                return
            case Key.returnKey, Key.t, Key.escape:
                browsingPad = false
                interpreter.appendLine("browser closed", kind: .browse)
                return
            default:
                break // fall through for non-browser keys (space, A/D, etc.)
            }
        }

        switch keyCode {
        case Key.space:
            if engine.transport.isPlaying {
                let loopSec = Double(engine.transport.loopLengthFrames) / Transport.sampleRate
                interpreter.appendLine("■ paused @ \(engine.transport.bpm)bpm \(engine.transport.barCount) bars (\(String(format: "%.1f", loopSec))s)", kind: .transport)
            } else {
                let loopSec = Double(engine.transport.loopLengthFrames) / Transport.sampleRate
                interpreter.appendLine("▶ loop start — \(engine.transport.barCount) bars @ \(engine.transport.bpm)bpm (\(String(format: "%.1f", loopSec))s)", kind: .transport)
            }
            engine.togglePlay()
        case Key.g:
            if !engine.transport.isPlaying {
                engine.togglePlay()
                let loopSec = Double(engine.transport.loopLengthFrames) / Transport.sampleRate
                interpreter.appendLine("▶ god mode — \(engine.transport.barCount) bars @ \(engine.transport.bpm)bpm (\(String(format: "%.1f", loopSec))s)", kind: .capture)
                engine.toggleCapture()
                interpreter.appendLine("capture armed — next loop boundary", kind: .capture)
            } else {
                engine.toggleCapture()
                switch engine.capture.state {
                case .armed:
                    interpreter.appendLine("capture armed — next loop boundary", kind: .capture)
                case .idle:
                    interpreter.appendLine("capture disarmed", kind: .capture)
                case .recording:
                    break
                }
            }
        case Key.m:
            engine.toggleMetronome()
            interpreter.appendLine("metronome \(engine.metronome.isOn ? "on" : "off")", kind: .state)
        case Key.t:
            browsingPad.toggle()
            if browsingPad {
                let folder = PadBank.spliceFolderNames[engine.activePadIndex]
                interpreter.appendLine("browser open → \(folder)", kind: .browse)
                if let name = browserFileName() {
                    interpreter.appendLine("browse → \(name)", kind: .browse)
                }
            }
        case Key.a:
            engine.activePadIndex = (engine.activePadIndex - 1 + 8) % 8
            interpreter.appendLine("pad \(engine.activePadIndex + 1) → \(padName(engine.activePadIndex))", kind: .state)
        case Key.d:
            engine.activePadIndex = (engine.activePadIndex + 1) % 8
            interpreter.appendLine("pad \(engine.activePadIndex + 1) → \(padName(engine.activePadIndex))", kind: .state)
        case Key.q:
            if !engine.layers[engine.activePadIndex].isMuted {
                engine.toggleMute(layer: engine.activePadIndex)
                interpreter.appendLine("pad \(engine.activePadIndex + 1) \(padName(engine.activePadIndex)) frozen", kind: .state)
            }
        case Key.e:
            if engine.layers[engine.activePadIndex].isMuted {
                engine.toggleMute(layer: engine.activePadIndex)
                interpreter.appendLine("pad \(engine.activePadIndex + 1) \(padName(engine.activePadIndex)) hot", kind: .state)
            }
        case Key.c:
            let name = padName(engine.activePadIndex)
            engine.clearLayer(engine.activePadIndex)
            interpreter.appendLine("pad \(engine.activePadIndex + 1) \(name) cleared", kind: .state)
        case Key.b:
            bpmMode = true
            bpmInput = ""
            // Snap to nearest preset
            let currentBpm = engine.transport.bpm
            let presets = Self.bpmPresets
            bpmPresetIndex = presets.enumerated().min(by: { abs($0.element.bpm - currentBpm) < abs($1.element.bpm - currentBpm) })?.offset ?? 0
            let p = presets[bpmPresetIndex]
            interpreter.appendLine("bpm mode → \(p.bpm) \(p.mood) [W↑ S↓ or type]", kind: .transport)
        case Key.escape:
            engine.stop()
            interpreter.appendLine("■ stopped", kind: .transport)
        case Key.leftBracket:
            engine.cycleBarCount(forward: false)
            interpreter.appendLine("bars → \(engine.transport.barCount)", kind: .transport)
        case Key.rightBracket:
            engine.cycleBarCount(forward: true)
            interpreter.appendLine("bars → \(engine.transport.barCount)", kind: .transport)
        case Key.v:
            masterVolumeMode.toggle()
        case Key.z:
            engine.undoLastClear()
            interpreter.appendLine("undo clear → pad \(engine.activePadIndex + 1)")
        default:
            break
        }

        if let c = chars?.first {
            switch c {
            case "?":
                showKeyReference.toggle()
            case "0"..."9":
                let digit = Float(c.asciiValue! - Character("0").asciiValue!)
                if masterVolumeMode {
                    engine.setMasterVolume(digit / 9.0)
                    interpreter.appendLine("master vol → \(Int(engine.masterVolume * 100))%", kind: .state)
                } else {
                    engine.setLayerVolume(engine.activePadIndex, volume: digit / 9.0)
                    interpreter.appendLine("pad \(engine.activePadIndex + 1) vol → \(Int(digit / 9.0 * 100))%", kind: .state)
                }
            default: break
            }
        }
    }
}

// MARK: - Key label

struct KeyLabel: View {
    let key: String
    let action: String

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .foregroundColor(Theme.orange)
            Text(action)
                .foregroundColor(.white)
        }
        .font(Theme.mono)
    }
}

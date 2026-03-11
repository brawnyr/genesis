import SwiftUI
import AppKit

// MARK: - Key capture NSView

class KeyCaptureView: NSView {
    var onKeyDown: ((UInt16, String?) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool { true }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event.keyCode, event.characters)
    }
}

struct KeyCaptureRepresentable: NSViewRepresentable {
    let onKeyDown: (UInt16, String?) -> Void

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
            engine.activePadIndex = (engine.activePadIndex - 1 + 8) % 8
        case Key.d:
            engine.activePadIndex = (engine.activePadIndex + 1) % 8
        case Key.w:
            engine.toggleMute(layer: engine.activePadIndex)
        case Key.c:
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

// MARK: - Key label

struct KeyLabel: View {
    let key: String
    let action: String

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .foregroundColor(Theme.blue)
            Text(action)
                .foregroundColor(Theme.text)
        }
        .font(Theme.monoSmall)
    }
}

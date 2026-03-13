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
    @State var showKeyReference = false
    enum EditMode {
        case normal
        case bpm
        case browse
    }
    @State var mode: EditMode = .normal
    @State var browserIndex: Int = 0
    @State var bpmInput = ""
    @State var bpmPresetIndex = 0

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
                        browsingPad: Binding(
                            get: { mode == .browse },
                            set: { mode = $0 ? .browse : .normal }
                        ),
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
                    KeyLabel(key: "F", action: "arm")
                    KeyLabel(key: "Q", action: "mute")
                    KeyLabel(key: "C", action: "clear")
                    KeyLabel(key: "B", action: "bpm")
                    KeyLabel(key: "[]", action: "bars")
                    KeyLabel(key: "0-9", action: "vol")
                    KeyLabel(key: "V", action: "swing")
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

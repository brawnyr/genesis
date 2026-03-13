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
    @ObservedObject var engine: GenesisEngine
    @ObservedObject var interpreter: EngineEventInterpreter
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
                // Hotkey HUD — top
                HotkeyHUD()

                HStack(spacing: 0) {
                    // Left: terminal log + transport
                    VStack(spacing: 0) {
                        TerminalTextLayer(interpreter: interpreter, engine: engine)
                        TransportHUD(engine: engine)
                    }
                    .frame(width: 480)
                    .background(Theme.canvasBg)

                    // Center: trigger roll — fills the gap edge to edge
                    TriggerRollView(engine: engine)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Right: inspector panel
                    InspectorPanelView(
                        engine: engine,
                        browsingPad: Binding(
                            get: { mode == .browse },
                            set: { mode = $0 ? .browse : .normal }
                        ),
                        browserIndex: $browserIndex
                    )
                }
            }

        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

// MARK: - Hotkey HUD

struct HotkeyHUD: View {
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 20) {
                // Transport — blue
                HotkeyGroup(color: Theme.blue, items: [
                    ("SPC", "play/stop"), ("ESC", "stop"), ("G", "record"),
                ])

                // Pads — orange
                HotkeyGroup(color: Theme.orange, items: [
                    ("A/D", "pad ←→"), ("⇧F", "queue"),
                    ("T", "browse"), ("W/S", "nav"),
                ])

                // Muting — red
                HotkeyGroup(color: Theme.red, items: [
                    ("Q", "mute"), ("⇧Q", "master"), ("⌘⇧Q", "all"),
                ])
            }

            HStack(spacing: 20) {
                // Muting continued
                HotkeyGroup(color: Theme.red, items: [
                    ("N", "queued"), ("X", "choke"),
                ])

                // Sound — green
                HotkeyGroup(color: Theme.green, items: [
                    ("0-9", "vol"), ("P", "velocity"),
                    ("M", "metro"), ("R", "looper"),
                ])

                // Edit — amber
                HotkeyGroup(color: Theme.amber, items: [
                    ("C", "clear"), ("Z", "undo"), ("B", "bpm"), ("[]", "bars"),
                ])

                // Oracle
                HotkeyGroup(color: Theme.green, items: [
                    ("O", "oracle"),
                ])
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.065, green: 0.06, blue: 0.053))
    }
}

struct HotkeyGroup: View {
    let color: Color
    let items: [(String, String)]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items, id: \.0) { key, action in
                HStack(spacing: 3) {
                    Text(key)
                        .font(.system(size: 16, design: .monospaced).bold())
                        .foregroundColor(color)
                        .shadow(color: color.opacity(0.5), radius: 5)
                    Text(action)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .shadow(color: .white.opacity(0.3), radius: 4)
                }
            }
        }
    }
}

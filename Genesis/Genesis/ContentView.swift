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
    @State var cachedBrowserFiles: [URL] = []
    @State var cachedBrowserPadIndex: Int = -1

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            KeyCaptureRepresentable { keyCode, chars, modifiers in
                handleKey(keyCode: keyCode, chars: chars, modifiers: modifiers)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 0) {
                // Left: main content area
                VStack(spacing: 0) {
                    // Hotkey HUD — top
                    HotkeyHUD()

                    // Terminal
                    TerminalTextLayer(interpreter: interpreter, engine: engine)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.canvasBg)

                    // Bottom bar: transport + pads
                    HStack(spacing: 0) {
                        GHUD(engine: engine)
                            .frame(width: 420)

                        PadSelect(engine: engine)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: 220)
                    .background(Theme.canvasBg)
                }

                // Right: full-height inspect panel with integrated browser
                PadInspectPanel(
                    engine: engine,
                    browsingPad: Binding(
                        get: { mode == .browse },
                        set: { mode = $0 ? .browse : .normal }
                    ),
                    browserIndex: $browserIndex
                )
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
                // Transport — sage
                HotkeyGroup(color: Theme.sage, items: [
                    ("SPC", "play/stop"), ("ESC", "stop"), ("G", "record"),
                ])

                // Pads — terracotta
                HotkeyGroup(color: Theme.terracotta, items: [
                    ("A/D", "pad ←→"),
                    ("T", "browse"), ("W/S", "nav"),
                ])

                // Muting — clay
                HotkeyGroup(color: Theme.clay, items: [
                    ("Q", "mute"), ("⇧Q", "master"), ("⌘⇧Q", "all"),
                ])
            }

            HStack(spacing: 20) {
                // Muting continued
                HotkeyGroup(color: Theme.clay, items: [
                    ("X", "choke"),
                ])

                // Sound — forest
                HotkeyGroup(color: Theme.forest, items: [
                    ("NUM0-9", "vol"), ("P", "velocity"),
                    ("M", "metro"), ("R", "looper"),
                ])

                // Edit — wheat
                HotkeyGroup(color: Theme.wheat, items: [
                    ("C", "clear"), ("Z", "undo"), ("B", "bpm"), ("[]", "bars"),
                ])

                // Oracle
                HotkeyGroup(color: Theme.forest, items: [
                    ("O", "oracle"),
                ])
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Theme.canvasBg)
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
                        .shadow(color: color.opacity(0.3), radius: 4)
                    Text(action)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(Theme.text.opacity(0.6))
                }
            }
        }
    }
}

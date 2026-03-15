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

            HStack(spacing: 1) {
                // Left: main content area
                VStack(spacing: 0) {
                    // Hotkey HUD — top
                    HotkeyHUD()

                    // Separator between HotkeyHUD and terminal
                    Rectangle().fill(Theme.separator).frame(height: 1)

                    // Terminal
                    ZStack(alignment: .topLeading) {
                        TerminalTextLayer(interpreter: interpreter, engine: engine)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Theme.canvasBg)

                        // TERMINAL zone title
                        SectionTitle(text: "TERMINAL")
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        // BEAT_TRACKER_HUD — centered floating overlay
                        VStack {
                            Spacer()
                            BeatTrackerHUD(engine: engine)
                                .padding(.bottom, 12)
                        }
                    }

                    // Separator between terminal and bottom bar
                    Rectangle().fill(Theme.separator).frame(height: 1)

                    // Bottom bar: master + pads
                    HStack(spacing: 0) {
                        GHUD(engine: engine)
                            .frame(width: 360)

                        // Separator between GHUD and PadSelect
                        Rectangle().fill(Theme.separator).frame(width: 1)

                        PadSelect(engine: engine)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: 240)
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
        .frame(minWidth: 960, minHeight: 640)
    }
}

// MARK: - Hotkey HUD

struct HotkeyHUD: View {
    var body: some View {
        VStack(spacing: 8) {
            SectionTitle(text: "HOTKEYS")
                .padding(.horizontal, 0)
            HStack(spacing: 24) {
                // Transport — sage
                HotkeyGroup(color: Theme.sage, items: [
                    ("SPC", "play/stop"), ("ESC", "stop"), ("R", "rec"),
                ])

                // Pads — chrome
                HotkeyGroup(color: Theme.chrome, items: [
                    ("←→", "pad"), ("⇧T", "browse"), ("W/S", "nav"),
                ])

                // Muting — clay
                HotkeyGroup(color: Theme.clay, items: [
                    ("Q", "mute"), ("⇧Q", "master"), ("⌘⇧Q", "all"),
                ])
            }

            HStack(spacing: 24) {
                // Muting continued
                HotkeyGroup(color: Theme.clay, items: [
                    ("X", "choke"),
                ])

                // Sound — forest
                HotkeyGroup(color: Theme.forest, items: [
                    ("NUM0-9", "vol"), ("V", "velocity"),
                    ("M", "metro"), ("T", "looper"),
                ])

                // Edit — wheat
                HotkeyGroup(color: Theme.wheat, items: [
                    ("C", "clear"), ("Z", "undo"), ("B", "bpm"), ("Y", "bars"), ("G", "bounce"),
                ])

                // Oracle
                HotkeyGroup(color: Theme.forest, items: [
                    ("O", "oracle"),
                ])
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Theme.canvasBg)
    }
}

struct HotkeyGroup: View {
    let color: Color
    let items: [(String, String)]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(items, id: \.0) { key, action in
                HStack(spacing: 3) {
                    Text(key)
                        .font(Theme.monoLarge)
                        .foregroundColor(color)
                        .shadow(color: color.opacity(0.3), radius: 4)
                    Text(action)
                        .font(Theme.monoSmall)
                        .foregroundColor(Theme.text.opacity(0.5))
                }
            }
        }
    }
}

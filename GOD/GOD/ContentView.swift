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
    @ObservedObject var terminalState: TerminalState
    @State private var showSetup = false
    @State private var showKeyReference = false
    @State private var showTerminal = true

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            KeyCaptureRepresentable { keyCode, chars in
                handleKey(keyCode: keyCode, chars: chars)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // Left: Instrument panel
                    VStack(spacing: 20) {
                        TransportView(engine: engine)
                            .padding(.top, 16)

                        LoopBarView(engine: engine)

                        ChannelListView(engine: engine)
                            .padding(.vertical, 8)

                        Spacer()

                        CaptureIndicatorView(engine: engine)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)

                    if showTerminal {
                        // Right: Genesis Terminal
                        GenesisTerminalView(state: terminalState)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Bottom: Tips + key strip (full width)
                VStack(spacing: 4) {
                    TipView()
                        .padding(.vertical, 4)

                    HStack(spacing: 14) {
                        KeyLabel(key: "SPC", action: "play")
                        KeyLabel(key: "G", action: "god")
                        KeyLabel(key: "M", action: "metro")
                        KeyLabel(key: "S", action: "setup")
                        KeyLabel(key: "↑↓", action: "bpm")
                        KeyLabel(key: "[]", action: "bars")
                        KeyLabel(key: "-+", action: "vol")
                        KeyLabel(key: "1-8", action: "mute")
                        KeyLabel(key: "Z", action: "undo")
                        KeyLabel(key: "T", action: "term")
                        KeyLabel(key: "?", action: "help")
                    }
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, 24)
            }

            if showKeyReference {
                KeyReferenceOverlay(isVisible: $showKeyReference)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .sheet(isPresented: $showSetup) {
            SetupView(engine: engine, isPresented: $showSetup)
                .frame(width: 500, height: 500)
        }
    }

    // macOS virtual key codes
    private enum Key {
        static let space: UInt16 = 49
        static let g: UInt16 = 5
        static let m: UInt16 = 46
        static let s: UInt16 = 1
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
        case Key.s:
            showSetup = true
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
        case Key.t:
            showTerminal.toggle()
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
            case "1": engine.toggleMute(layer: 0)
            case "2": engine.toggleMute(layer: 1)
            case "3": engine.toggleMute(layer: 2)
            case "4": engine.toggleMute(layer: 3)
            case "5": engine.toggleMute(layer: 4)
            case "6": engine.toggleMute(layer: 5)
            case "7": engine.toggleMute(layer: 6)
            case "8": engine.toggleMute(layer: 7)
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

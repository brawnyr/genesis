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
    @State private var showSetup = false
    @State private var showKeyReference = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            KeyCaptureRepresentable { keyCode, chars in
                handleKey(keyCode: keyCode, chars: chars)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 20) {
                TransportView(engine: engine)
                    .padding(.top, 16)

                LoopBarView(engine: engine)

                ChannelListView(engine: engine)
                    .padding(.vertical, 8)

                Spacer()

                CaptureIndicatorView(engine: engine)

                TipView()
                    .padding(.vertical, 4)

                // Key strip
                HStack(spacing: 14) {
                    KeyLabel(key: "SPC", action: "play")
                    KeyLabel(key: "G", action: "god")
                    KeyLabel(key: "M", action: "metro")
                    KeyLabel(key: "S", action: "setup")
                    KeyLabel(key: "↑↓", action: "bpm")
                    KeyLabel(key: "[]", action: "bars")
                    KeyLabel(key: "-+", action: "vol")
                    KeyLabel(key: "1-8", action: "mute")
                    KeyLabel(key: "?", action: "help")
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)

            if showKeyReference {
                KeyReferenceOverlay(isVisible: $showKeyReference)
            }
        }
        .sheet(isPresented: $showSetup) {
            SetupView(engine: engine, isPresented: $showSetup)
                .frame(width: 500, height: 500)
        }
    }

    private func handleKey(keyCode: UInt16, chars: String?) {
        switch keyCode {
        case 49: // space
            engine.togglePlay()
        case 5: // g
            engine.toggleCapture()
        case 46: // m
            engine.toggleMetronome()
        case 1: // s
            showSetup = true
        case 126: // up arrow
            engine.setBPM(engine.transport.bpm + 1)
        case 125: // down arrow
            engine.setBPM(engine.transport.bpm - 1)
        case 53: // escape
            engine.stop()
        case 33: // [
            engine.cycleBarCount(forward: false)
        case 30: // ]
            engine.cycleBarCount(forward: true)
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

import SwiftUI

struct KeyReferenceOverlay: View {
    @Binding var isVisible: Bool

    private let shortcuts: [(key: String, action: String)] = [
        ("SPC", "play / stop"),
        ("G", "god capture"),
        ("A", "select pad left"),
        ("D", "select pad right"),
        ("⇧1-8", "jump to pad 1-8"),
        ("Q", "cool (mute) active pad"),
        ("E", "hot (unmute) active pad"),
        ("T", "browse samples for pad"),
        ("W/S", "browse + auto-load sample"),
        ("⏎/T/ESC", "close browser"),
        ("M", "metronome"),
        ("B", "bpm mode (W/S presets or type)"),
        ("[", "fewer bars"),
        ("]", "more bars"),
        ("V", "toggle master volume mode"),
        ("0-9", "volume (master or pad)"),
        ("Z", "undo clear"),
        ("X", "cut mode"),
        ("N", "toggle instant / next loop"),
        ("C", "clear active pad"),
        ("ESC", "stop"),
        ("?", "this help"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("KEYS")
                .font(Theme.monoLarge)
                .foregroundColor(Theme.text)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(shortcuts, id: \.key) { shortcut in
                    HStack(spacing: 20) {
                        Text(shortcut.key)
                            .foregroundColor(Theme.blue)
                            .frame(width: 60, alignment: .trailing)
                        Text(shortcut.action)
                            .foregroundColor(Theme.text)
                    }
                }
            }

            Text("press ? to close")
                .font(Theme.monoSmall)
                .foregroundColor(Theme.subtle)
                .padding(.top, 12)
        }
        .font(Theme.mono)
        .padding(40)
        .background(Theme.bg.opacity(0.95))
    }
}

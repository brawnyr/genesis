import SwiftUI

struct KeyReferenceOverlay: View {
    @Binding var isVisible: Bool

    private let shortcuts: [(key: String, action: String)] = [
        ("SPC", "play / stop"),
        ("G", "god capture"),
        ("A", "select pad left"),
        ("D", "select pad right"),
        ("W", "mute / unmute active pad"),
        ("M", "metronome"),
        ("↑", "bpm +1"),
        ("↓", "bpm -1"),
        ("[", "fewer bars"),
        ("]", "more bars"),
        ("-", "volume down"),
        ("+", "volume up"),
        ("Z", "undo clear"),
        ("C", "clear active pad"),
        ("T", "setup pads"),
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

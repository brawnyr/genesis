import SwiftUI

struct KeyReferenceOverlay: View {
    @Binding var isVisible: Bool

    private let shortcuts: [(key: String, action: String)] = [
        ("SPC", "play / stop"),
        ("G", "god capture"),
        ("M", "metronome"),
        ("↑", "bpm +1"),
        ("↓", "bpm -1"),
        ("1-8", "mute / unmute"),
        ("/", "command input"),
        ("ESC", "stop / dismiss"),
        ("?", "this help"),
    ]

    var body: some View {
        VStack(spacing: 12) {
            Text("KEYS")
                .font(Theme.monoLarge)
                .foregroundColor(Theme.text)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(shortcuts, id: \.key) { shortcut in
                    HStack(spacing: 16) {
                        Text(shortcut.key)
                            .foregroundColor(Theme.blue)
                            .frame(width: 50, alignment: .trailing)
                        Text(shortcut.action)
                            .foregroundColor(Theme.text)
                    }
                }
            }

            Text("press any key to close")
                .font(Theme.monoSmall)
                .foregroundColor(Theme.subtle)
                .padding(.top, 8)
        }
        .font(Theme.mono)
        .padding(40)
        .background(Theme.bg.opacity(0.95))
    }
}

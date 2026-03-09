import SwiftUI

struct TransportView: View {
    @ObservedObject var engine: GodEngine

    var body: some View {
        HStack(spacing: 16) {
            Text(engine.transport.isPlaying ? "▶" : "■")
                .foregroundColor(engine.transport.isPlaying ? Theme.green : Theme.dim)

            Text("\(engine.transport.bpm) BPM")
                .foregroundColor(Theme.text)

            Text("·")
                .foregroundColor(Theme.muted)

            Text("\(engine.transport.barCount) BARS")
                .foregroundColor(Theme.text)

            Text("·")
                .foregroundColor(Theme.muted)

            Text("♩ \(engine.metronome.isOn ? "ON" : "OFF")")
                .foregroundColor(engine.metronome.isOn ? Theme.accent : Theme.dim)
        }
        .font(Theme.mono)
    }
}

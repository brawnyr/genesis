import SwiftUI

struct TransportView: View {
    @ObservedObject var engine: GodEngine

    var body: some View {
        HStack(spacing: 16) {
            // Play state
            Text(engine.transport.isPlaying ? "▶" : "■")
                .foregroundColor(engine.transport.isPlaying ? Theme.blue : Theme.subtle)
                .font(Theme.monoLarge)

            // BPM
            Text("\(engine.transport.bpm)")
                .foregroundColor(engine.transport.isPlaying ? Theme.text : Theme.subtle)
                .font(.system(size: 18, design: .monospaced).bold())
            Text("bpm")
                .foregroundColor(Theme.subtle)
                .font(Theme.monoSmall)

            // Bar count
            HStack(spacing: 2) {
                Text("[").foregroundColor(Theme.blue)
                Text("\(engine.transport.barCount)").foregroundColor(Theme.text)
                Text("]").foregroundColor(Theme.blue)
                Text("bars").foregroundColor(Theme.subtle)
            }
            .font(Theme.monoSmall)

            // Metronome
            Text("♩ \(engine.metronome.isOn ? "on" : "off")")
                .foregroundColor(engine.metronome.isOn ? Theme.blue : Theme.subtle)
                .font(Theme.monoSmall)

            // Beat counter
            if engine.transport.isPlaying {
                Text("beat \(engine.transport.currentBeat)")
                    .foregroundColor(Theme.blue)
                    .font(Theme.monoSmall)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.122, green: 0.118, blue: 0.106))  // #1f1e1b
    }
}

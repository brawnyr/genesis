import SwiftUI

struct TransportView: View {
    @ObservedObject var engine: GodEngine

    private var currentBeat: Int {
        let beatLength = engine.metronome.beatLengthFrames(
            bpm: engine.transport.bpm,
            sampleRate: Transport.sampleRate
        )
        guard beatLength > 0 else { return 1 }
        return (engine.transport.position / beatLength) % (engine.transport.barCount * 4) + 1
    }

    var body: some View {
        HStack(spacing: 20) {
            Text(engine.transport.isPlaying ? "▶" : "■")
                .foregroundColor(engine.transport.isPlaying ? Theme.blue : Theme.text)
                .font(Theme.monoLarge)

            Text("\(engine.transport.bpm) bpm")
                .foregroundColor(Theme.text)

            Text("\(engine.transport.barCount) bars")
                .foregroundColor(Theme.text)

            Text("♩ \(engine.metronome.isOn ? "on" : "off")")
                .foregroundColor(engine.metronome.isOn ? Theme.blue : Theme.text)

            Spacer()

            if engine.transport.isPlaying {
                Text("beat \(currentBeat)")
                    .foregroundColor(Theme.blue)
            }
        }
        .font(Theme.mono)
    }
}

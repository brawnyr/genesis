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
        VStack(spacing: 12) {
            // Top row: play state, bpm, bars, metronome, beat
            HStack(spacing: 20) {
                Text(engine.transport.isPlaying ? "▶" : "■")
                    .foregroundColor(engine.transport.isPlaying ? Theme.blue : Theme.text)
                    .font(Theme.monoLarge)

                Text("\(engine.transport.bpm) bpm")
                    .foregroundColor(Theme.text)

                // Bar count with bracket indicators
                HStack(spacing: 4) {
                    Text("[")
                        .foregroundColor(Theme.blue)
                    Text("\(engine.transport.barCount)")
                        .foregroundColor(Theme.text)
                    Text("]")
                        .foregroundColor(Theme.blue)
                    Text("bars")
                        .foregroundColor(Theme.text)
                }

                Text("♩ \(engine.metronome.isOn ? "on" : "off")")
                    .foregroundColor(engine.metronome.isOn ? Theme.blue : Theme.text)

                Spacer()

                if engine.transport.isPlaying {
                    Text("beat \(currentBeat)")
                        .foregroundColor(Theme.blue)
                }
            }
            .font(Theme.mono)

            // Master mixer row
            HStack(spacing: 12) {
                Text("master")
                    .foregroundColor(Theme.text)
                    .font(Theme.monoSmall)

                // Volume percentage
                Text("\(Int(engine.masterVolume * 100))%")
                    .foregroundColor(Theme.blue)
                    .font(Theme.monoSmall)
                    .frame(width: 50, alignment: .trailing)

                // Master signal meter
                SignalMeterView(level: engine.masterLevel)

                Spacer()
            }
        }
    }
}

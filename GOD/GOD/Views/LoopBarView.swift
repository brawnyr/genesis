import SwiftUI

struct LoopBarView: View {
    @ObservedObject var engine: GodEngine

    private var progress: Double {
        guard engine.transport.loopLengthFrames > 0 else { return 0 }
        return Double(engine.transport.position) / Double(engine.transport.loopLengthFrames)
    }

    private var currentBeat: Int {
        let beatLength = engine.metronome.beatLengthFrames(
            bpm: engine.transport.bpm,
            sampleRate: Transport.sampleRate
        )
        guard beatLength > 0 else { return 0 }
        return engine.transport.position / beatLength
    }

    private var totalBeats: Int {
        engine.transport.barCount * 4
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.muted.opacity(0.3))
                        .frame(height: 2)

                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * progress, height: 2)
                }
            }
            .frame(height: 2)

            HStack(spacing: 0) {
                ForEach(0..<totalBeats, id: \.self) { beat in
                    if beat > 0 { Spacer() }
                    if beat % 4 == 0 {
                        Text("\(beat / 4 + 1)")
                            .foregroundColor(currentBeat == beat ? Theme.accent : Theme.dim)
                    } else {
                        Text("·")
                            .foregroundColor(Theme.muted)
                    }
                }
            }
            .font(Theme.monoSmall)
        }
    }
}

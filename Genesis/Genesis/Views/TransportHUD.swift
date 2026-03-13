// Genesis/Genesis/Views/TransportHUD.swift
import SwiftUI

struct TransportHUD: View {
    @ObservedObject var engine: GenesisEngine

    private var isLooping: Bool { engine.capture.state == .on }

    private var secondsElapsed: Double {
        Double(engine.transport.position) / Transport.sampleRate
    }

    private var loopPositionString: String {
        let beatStr = EngineEventInterpreter.formatBeatPosition(
            framePosition: engine.transport.position,
            loopLengthFrames: engine.transport.loopLengthFrames,
            barCount: engine.transport.barCount
        )
        let sec = String(format: "%.1fs", secondsElapsed)
        return "\(beatStr) / \(sec)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)

            // Row 1: BPM big + bar count
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text("\(engine.transport.bpm)")
                    .font(.system(size: 32, design: .monospaced).bold())
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.5), radius: 8)
                Text("BPM")
                    .font(.system(size: 14, design: .monospaced).bold())
                    .foregroundColor(Theme.orange)
                    .shadow(color: Theme.orange.opacity(0.5), radius: 8)

                Text("\(engine.transport.barCount)")
                    .font(.system(size: 32, design: .monospaced).bold())
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.5), radius: 8)
                Text("BAR")
                    .font(.system(size: 14, design: .monospaced).bold())
                    .foregroundColor(Theme.orange)
                    .shadow(color: Theme.orange.opacity(0.5), radius: 8)

                if engine.transport.isPlaying {
                    Text("LOOP")
                        .font(.system(size: 14, design: .monospaced).bold())
                        .foregroundColor(Theme.orange)
                        .shadow(color: Theme.orange.opacity(0.5), radius: 8)
                    Text(loopPositionString)
                        .font(.system(size: 14, design: .monospaced).bold())
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.5), radius: 8)
                }
            }

            // Row 2: Master volume + live dB meter
            HStack(spacing: 8) {
                Text("MASTER VOL")
                    .font(.system(size: 12, design: .monospaced).bold())
                    .foregroundColor(Theme.orange)
                    .shadow(color: Theme.orange.opacity(0.5), radius: 8)
                Text("\(Int(engine.masterVolume * 100))")
                    .font(.system(size: 28, design: .monospaced).bold())
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.5), radius: 8)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Theme.orange.opacity(0.3), lineWidth: 1)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.orange.opacity(0.05))
                    )

                Text(formatMasterDb(engine.masterLevelDb))
                    .font(.system(size: 28, design: .monospaced).bold())
                    .foregroundColor(engine.masterLevelDb > 0 ? Theme.red : .white)
                    .shadow(color: (engine.masterLevelDb > 0 ? Theme.red : .white).opacity(0.5), radius: 8)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke((engine.masterLevelDb > 0 ? Theme.red : Theme.orange).opacity(0.3), lineWidth: 1)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill((engine.masterLevelDb > 0 ? Theme.red : Theme.orange).opacity(0.05))
                    )
                Text("dB")
                    .font(.system(size: 12, design: .monospaced).bold())
                    .foregroundColor(Theme.orange)
                    .shadow(color: Theme.orange.opacity(0.5), radius: 8)
            }

            // Row 3: Status badges
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Text("METRONOME")
                        .font(.system(size: 14, design: .monospaced).bold())
                        .foregroundColor(Theme.orange)
                        .shadow(color: Theme.orange.opacity(0.5), radius: 8)
                    Text(engine.metronome.isOn ? "ON" : "OFF")
                        .font(.system(size: 14, design: .monospaced).bold())
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.5), radius: 8)
                }

                if isLooping {
                    Text("LOOPER")
                        .font(.system(size: 14, design: .monospaced).bold())
                        .foregroundColor(Theme.red)
                        .shadow(color: Theme.red.opacity(0.5), radius: 8)
                }

            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatMasterDb(_ db: Float) -> String {
        if db == -.infinity || db < -60 { return "-inf" }
        return String(format: "%+.1f", db)
    }
}

// Genesis/Genesis/Views/TransportHUD.swift
import SwiftUI

struct TransportHUD: View {
    @ObservedObject var engine: GenesisEngine

    private var isLooping: Bool { engine.capture.state == .on }

    private var secondsElapsed: Double {
        Double(engine.transport.position) / Transport.sampleRate
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
                    .shadow(color: Theme.orange.opacity(0.9), radius: 0, x: 2, y: 2)
                    .shadow(color: Theme.orange.opacity(0.3), radius: 8)
                Text("BPM")
                    .font(.system(size: 14, design: .monospaced).bold())
                    .foregroundColor(Theme.orange.opacity(0.6))

                Text("\(engine.transport.barCount)")
                    .font(.system(size: 32, design: .monospaced).bold())
                    .foregroundColor(.white)
                    .shadow(color: Theme.orange.opacity(0.9), radius: 0, x: 2, y: 2)
                    .shadow(color: Theme.orange.opacity(0.3), radius: 8)
                Text("BAR")
                    .font(.system(size: 14, design: .monospaced).bold())
                    .foregroundColor(Theme.orange.opacity(0.6))

                if engine.transport.isPlaying {
                    Text(String(format: "%.1fs", secondsElapsed))
                        .font(.system(size: 14, design: .monospaced).bold())
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            // Row 2: Master volume — hero box
            HStack(spacing: 8) {
                Text("MASTER VOL")
                    .font(.system(size: 12, design: .monospaced).bold())
                    .foregroundColor(Theme.orange.opacity(0.6))
                Text("\(Int(engine.masterVolume * 100))")
                    .font(.system(size: 28, design: .monospaced).bold())
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.5), radius: 0, x: 1, y: 1)
                    .shadow(color: Theme.orange.opacity(0.4), radius: 8)
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
            }

            // Row 3: Status badges
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Text("METRONOME")
                        .font(.system(size: 14, design: .monospaced).bold())
                        .foregroundColor(Theme.orange)
                    Text(engine.metronome.isOn ? "ON" : "OFF")
                        .font(.system(size: 14, design: .monospaced).bold())
                        .foregroundColor(.white)
                }
                .shadow(color: engine.metronome.isOn ? .white.opacity(0.4) : .clear, radius: 0, x: 1, y: 1)

                if isLooping {
                    Text("LOOPER")
                        .font(.system(size: 14, design: .monospaced).bold())
                        .foregroundColor(Theme.red)
                        .shadow(color: .white.opacity(0.4), radius: 0, x: 1, y: 1)
                        .shadow(color: Theme.red.opacity(0.4), radius: 6)
                }

                if engine.transport.isPlaying {
                    Text("BEAT \(engine.transport.currentBeat)")
                        .font(.system(size: 14, design: .monospaced).bold())
                        .foregroundColor(Theme.orange)
                        .shadow(color: .white.opacity(0.4), radius: 0, x: 1, y: 1)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

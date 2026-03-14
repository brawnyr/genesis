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

    private var dbColor: Color {
        let db = engine.masterLevelDb
        if db > 0 { return Theme.red }
        if db > -6 { return Theme.orange }
        return .white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            // BPM
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(engine.transport.bpm)")
                    .font(.system(size: 36, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.6), radius: 2, x: 0, y: 1)
                    .shadow(color: .white.opacity(0.3), radius: 8)
                Text("BPM")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.orange)
                    .shadow(color: Theme.orange.opacity(0.6), radius: 6)
            }

            // BAR
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(engine.transport.barCount)")
                    .font(.system(size: 36, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.6), radius: 2, x: 0, y: 1)
                    .shadow(color: .white.opacity(0.3), radius: 8)
                Text("BAR")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.orange)
                    .shadow(color: Theme.orange.opacity(0.6), radius: 6)
            }

            // LOOP position
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("LOOP")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.orange)
                    .shadow(color: Theme.orange.opacity(0.6), radius: 6)
                if engine.transport.isPlaying {
                    Text(loopPositionString)
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.6), radius: 2, x: 0, y: 1)
                        .shadow(color: .white.opacity(0.3), radius: 8)
                } else {
                    Text("—")
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.3), radius: 6)
                }
            }

            // MASTER VOL
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("VOL")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.orange)
                    .shadow(color: Theme.orange.opacity(0.6), radius: 6)
                Text("\(Int(engine.masterVolume * 100))")
                    .font(.system(size: 30, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.6), radius: 2, x: 0, y: 1)
                    .shadow(color: .white.opacity(0.3), radius: 8)
            }

            // dB
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(formatMasterDb(engine.masterLevelDb))
                    .font(.system(size: 30, weight: .heavy, design: .monospaced))
                    .foregroundColor(dbColor)
                    .shadow(color: dbColor.opacity(0.6), radius: 2, x: 0, y: 1)
                    .shadow(color: dbColor.opacity(0.3), radius: 8)
                Text("dB")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.orange)
                    .shadow(color: Theme.orange.opacity(0.6), radius: 6)
            }

            // METRONOME
            HStack(spacing: 8) {
                Text("METRONOME")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.orange)
                    .shadow(color: Theme.orange.opacity(0.6), radius: 6)
                Text(engine.metronome.isOn ? "ON" : "OFF")
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.6), radius: 2, x: 0, y: 1)
                    .shadow(color: .white.opacity(0.3), radius: 6)
            }

            // LOOPER
            if isLooping {
                Text("LOOPER")
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .foregroundColor(Theme.red)
                    .shadow(color: Theme.red.opacity(0.7), radius: 2, x: 0, y: 1)
                    .shadow(color: Theme.red.opacity(0.5), radius: 8)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func formatMasterDb(_ db: Float) -> String {
        if db == -.infinity || db < -60 { return "-inf" }
        return String(format: "%+.1f", db)
    }
}

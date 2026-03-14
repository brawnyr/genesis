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

    // Fonts
    private static let bigNum = Font.custom("Futura-CondensedExtraBold", size: 38)
    private static let medNum = Font.custom("Futura-CondensedExtraBold", size: 28)
    private static let label = Font.custom("DINCondensed-Bold", size: 16)
    private static let labelSmall = Font.custom("DINCondensed-Bold", size: 14)
    private static let status = Font.custom("AvenirNextCondensed-Heavy", size: 15)

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {

            // BPM
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(engine.transport.bpm)")
                    .font(Self.bigNum)
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.7), radius: 1, x: 0, y: 1)
                    .shadow(color: .white.opacity(0.25), radius: 10)
                Text("BPM")
                    .font(Self.label)
                    .foregroundColor(Theme.orange)
                    .shadow(color: Theme.orange.opacity(0.6), radius: 6)
            }

            // BAR
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(engine.transport.barCount)")
                    .font(Self.bigNum)
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.7), radius: 1, x: 0, y: 1)
                    .shadow(color: .white.opacity(0.25), radius: 10)
                Text("BAR")
                    .font(Self.label)
                    .foregroundColor(Theme.orange)
                    .shadow(color: Theme.orange.opacity(0.6), radius: 6)
            }

            // LOOP position
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("LOOP")
                    .font(Self.label)
                    .foregroundColor(Theme.orange)
                    .shadow(color: Theme.orange.opacity(0.6), radius: 6)
                if engine.transport.isPlaying {
                    Text(loopPositionString)
                        .font(Self.medNum)
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.7), radius: 1, x: 0, y: 1)
                        .shadow(color: .white.opacity(0.25), radius: 10)
                } else {
                    Text("—")
                        .font(Self.medNum)
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.2), radius: 6)
                }
            }

            // VOL
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("VOL")
                    .font(Self.label)
                    .foregroundColor(Theme.orange)
                    .shadow(color: Theme.orange.opacity(0.6), radius: 6)
                Text("\(Int(engine.masterVolume * 100))")
                    .font(Self.medNum)
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.7), radius: 1, x: 0, y: 1)
                    .shadow(color: .white.opacity(0.25), radius: 10)
            }

            // dB
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatMasterDb(engine.masterLevelDb))
                    .font(Self.medNum)
                    .foregroundColor(dbColor)
                    .shadow(color: dbColor.opacity(0.7), radius: 1, x: 0, y: 1)
                    .shadow(color: dbColor.opacity(0.25), radius: 10)
                Text("dB")
                    .font(Self.labelSmall)
                    .foregroundColor(Theme.orange)
                    .shadow(color: Theme.orange.opacity(0.6), radius: 6)
            }

            // METRONOME
            HStack(spacing: 6) {
                Text("METRONOME")
                    .font(Self.status)
                    .foregroundColor(Theme.orange)
                    .shadow(color: Theme.orange.opacity(0.6), radius: 6)
                Text(engine.metronome.isOn ? "ON" : "OFF")
                    .font(Self.status)
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.7), radius: 1, x: 0, y: 1)
                    .shadow(color: .white.opacity(0.25), radius: 6)
            }

            // LOOPER
            if isLooping {
                Text("LOOPER")
                    .font(Self.status)
                    .foregroundColor(Theme.red)
                    .shadow(color: Theme.red.opacity(0.7), radius: 1, x: 0, y: 1)
                    .shadow(color: Theme.red.opacity(0.4), radius: 8)
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

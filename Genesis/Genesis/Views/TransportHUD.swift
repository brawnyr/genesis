// Genesis/Genesis/Views/TransportHUD.swift
import SwiftUI

struct TransportHUD: View {
    @ObservedObject var engine: GenesisEngine

    private var isLooping: Bool { engine.capture.state == .on }

    private var secondsElapsed: Double {
        Double(engine.transport.position) / Transport.sampleRate
    }

    private var beatPosition: String {
        EngineEventInterpreter.formatBeatPosition(
            framePosition: engine.transport.position,
            loopLengthFrames: engine.transport.loopLengthFrames,
            barCount: engine.transport.barCount
        )
    }

    private var dbColor: Color {
        let db = engine.masterLevelDb
        if db > 0 { return Theme.red }
        if db > -6 { return Theme.orange }
        return .white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // === TOP DISPLAY — BPM + BARS like an LCD readout ===
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text("\(engine.transport.bpm)")
                    .font(.custom("HelveticaNeue-Light", size: 40))
                    .foregroundColor(.white)
                Text(" ")
                Text("BPM")
                    .font(.custom("HelveticaNeue-Medium", size: 14))
                    .foregroundColor(Theme.orange)
                Spacer()
                Text("\(engine.transport.barCount)")
                    .font(.custom("HelveticaNeue-Light", size: 40))
                    .foregroundColor(.white)
                Text(" ")
                Text("BAR")
                    .font(.custom("HelveticaNeue-Medium", size: 14))
                    .foregroundColor(Theme.orange)
            }
            .shadow(color: .white.opacity(0.4), radius: 6)
            .padding(.bottom, 4)

            // Thin rule
            Rectangle().fill(Theme.orange.opacity(0.2)).frame(height: 1)
                .padding(.bottom, 6)

            // === LOOP POSITION — the counter ===
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text("LOOP")
                    .font(.custom("HelveticaNeue-Medium", size: 13))
                    .foregroundColor(Theme.orange)
                    .frame(width: 42, alignment: .leading)
                if engine.transport.isPlaying {
                    Text(beatPosition)
                        .font(.custom("HelveticaNeue-Light", size: 28))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.4), radius: 6)
                    Text("  ")
                    Text(String(format: "%.1fs", secondsElapsed))
                        .font(.custom("HelveticaNeue-Medium", size: 13))
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    Text("—")
                        .font(.custom("HelveticaNeue-Light", size: 28))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(.bottom, 4)

            // Thin rule
            Rectangle().fill(Theme.orange.opacity(0.2)).frame(height: 1)
                .padding(.bottom, 6)

            // === VOLUME + dB — side by side ===
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text("VOL")
                    .font(.custom("HelveticaNeue-Medium", size: 13))
                    .foregroundColor(Theme.orange)
                    .frame(width: 42, alignment: .leading)
                Text("\(Int(engine.masterVolume * 100))")
                    .font(.custom("HelveticaNeue-Light", size: 28))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.4), radius: 6)
                Spacer()
                Text(formatMasterDb(engine.masterLevelDb))
                    .font(.custom("HelveticaNeue-Light", size: 28))
                    .foregroundColor(dbColor)
                    .shadow(color: dbColor.opacity(0.4), radius: 6)
                Text(" ")
                Text("dB")
                    .font(.custom("HelveticaNeue-Medium", size: 13))
                    .foregroundColor(Theme.orange)
            }
            .padding(.bottom, 4)

            // Thin rule
            Rectangle().fill(Theme.orange.opacity(0.2)).frame(height: 1)
                .padding(.bottom, 6)

            // === STATUS ROW ===
            HStack(spacing: 16) {
                // Metronome
                HStack(spacing: 4) {
                    Circle()
                        .fill(engine.metronome.isOn ? Theme.orange : Theme.orange.opacity(0.15))
                        .frame(width: 7, height: 7)
                        .shadow(color: engine.metronome.isOn ? Theme.orange.opacity(0.6) : .clear, radius: 4)
                    Text("MET")
                        .font(.custom("HelveticaNeue-Medium", size: 13))
                        .foregroundColor(engine.metronome.isOn ? Theme.orange : Theme.orange.opacity(0.3))
                }

                // Looper
                if isLooping {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Theme.red)
                            .frame(width: 7, height: 7)
                            .shadow(color: Theme.red.opacity(0.6), radius: 4)
                        Text("REC")
                            .font(.custom("HelveticaNeue-Medium", size: 13))
                            .foregroundColor(Theme.red)
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func formatMasterDb(_ db: Float) -> String {
        if db == -.infinity || db < -60 { return "-inf" }
        return String(format: "%+.1f", db)
    }
}

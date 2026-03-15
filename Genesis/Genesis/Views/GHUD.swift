// Genesis/Genesis/Views/GHUD.swift
import SwiftUI

struct GHUD: View {
    @ObservedObject var engine: GenesisEngine

    private var dbColor: Color {
        let db = engine.masterLevelDb
        if db > 0 { return Theme.clay }
        if db > -6 { return Theme.terracotta }
        return Theme.chrome
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // === TITLE ===
            SectionTitle(text: "MASTER")
                .padding(.bottom, 6)

            // === BPM + BARS ===
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text("\(engine.transport.bpm)")
                    .font(Theme.hero)
                    .foregroundColor(Theme.chrome)
                    .shadow(color: Theme.electric.opacity(0.25), radius: 8)
                Text(" ")
                Text("BPM")
                    .font(Theme.monoSmall.bold())
                    .foregroundColor(Theme.sage)
                Spacer()
                Text("\(engine.transport.barCount)")
                    .font(Theme.hero)
                    .foregroundColor(Theme.chrome)
                    .shadow(color: Theme.electric.opacity(0.25), radius: 8)
                Text(" ")
                Text("BAR")
                    .font(Theme.monoSmall.bold())
                    .foregroundColor(Theme.sage)
            }
            .padding(.bottom, 4)

            // Thin rule
            Rectangle().fill(Theme.separator).frame(height: 1)
                .padding(.bottom, 6)

            // === VOLUME + dB ===
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text("VOL")
                    .font(Theme.monoSmall.bold())
                    .foregroundColor(Theme.sage)
                    .shadow(color: Theme.electric.opacity(0.25), radius: 4)
                    .frame(width: 36, alignment: .leading)
                Text("\(Int(engine.masterVolume * 100))")
                    .font(Theme.hero)
                    .foregroundColor(Theme.chrome)
                    .shadow(color: Theme.electric.opacity(0.25), radius: 8)
                Spacer()
                Text(formatMasterDb(engine.masterLevelDb))
                    .font(Theme.hero)
                    .foregroundColor(dbColor)
                    .shadow(color: Theme.electric.opacity(0.25), radius: 8)
                Text(" ")
                Text("dB")
                    .font(Theme.monoSmall.bold())
                    .foregroundColor(Theme.sage)
                    .shadow(color: Theme.electric.opacity(0.25), radius: 4)
            }
            .padding(.bottom, 4)

            // Thin rule
            Rectangle().fill(Theme.separator).frame(height: 1)
                .padding(.bottom, 6)

            // === VELOCITY MODE ===
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(engine.velocityMode == .full ? Theme.sage : Theme.subtle)
                        .frame(width: 9, height: 9)
                        .shadow(color: engine.velocityMode == .full ? Theme.sage.opacity(0.4) : .clear, radius: 3)
                    Text("VEL \(engine.velocityMode.rawValue.uppercased())")
                        .font(Theme.monoSmall.bold())
                        .foregroundColor(engine.velocityMode == .full ? Theme.chrome : Theme.subtle)
                }

                // Metronome
                HStack(spacing: 4) {
                    Circle()
                        .fill(engine.metronome.isOn ? Theme.sage : Theme.subtle)
                        .frame(width: 9, height: 9)
                        .shadow(color: engine.metronome.isOn ? Theme.sage.opacity(0.4) : .clear, radius: 3)
                    Text("METRO")
                        .font(Theme.monoSmall.bold())
                        .foregroundColor(engine.metronome.isOn ? Theme.chrome : Theme.subtle)
                }

                // Looper
                HStack(spacing: 4) {
                    Circle()
                        .fill(engine.capture.state == .on ? Theme.clay : Theme.subtle)
                        .frame(width: 9, height: 9)
                        .shadow(color: engine.capture.state == .on ? Theme.clay.opacity(0.4) : .clear, radius: 3)
                    Text("REC")
                        .font(Theme.monoSmall.bold())
                        .foregroundColor(engine.capture.state == .on ? Theme.clay : Theme.subtle)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func formatMasterDb(_ db: Float) -> String {
        if db == -.infinity || db < -60 { return "-inf" }
        return String(format: "%+.1f", db)
    }
}

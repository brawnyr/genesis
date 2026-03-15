// Genesis/Genesis/Views/GHUD.swift
import SwiftUI

struct GHUD: View {
    @ObservedObject var engine: GenesisEngine

    private var dbColor: Color {
        let db = engine.masterLevelDb
        if db > 0 { return Theme.clay }
        if db > -6 { return Theme.terracotta }
        return Theme.text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // === TITLE ===
            Text("MASTER")
                .font(.system(size: 11, design: .monospaced).bold())
                .foregroundColor(Theme.terracotta)
                .shadow(color: Theme.terracotta.opacity(0.3), radius: 4)
                .padding(.bottom, 6)

            // === VOLUME + dB ===
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text("VOL")
                    .font(.system(size: 12, design: .monospaced).bold())
                    .foregroundColor(Theme.terracotta)
                    .shadow(color: Theme.terracotta.opacity(0.3), radius: 4)
                    .frame(width: 36, alignment: .leading)
                Text("\(Int(engine.masterVolume * 100))")
                    .font(.system(size: 36, design: .monospaced).bold())
                    .foregroundColor(Theme.text)
                    .shadow(color: Theme.text.opacity(0.2), radius: 4)
                Spacer()
                Text(formatMasterDb(engine.masterLevelDb))
                    .font(.system(size: 36, design: .monospaced).bold())
                    .foregroundColor(dbColor)
                    .shadow(color: dbColor.opacity(0.2), radius: 4)
                Text(" ")
                Text("dB")
                    .font(.system(size: 12, design: .monospaced).bold())
                    .foregroundColor(Theme.terracotta)
                    .shadow(color: Theme.terracotta.opacity(0.3), radius: 4)
            }
            .padding(.bottom, 4)

            // Thin rule
            Rectangle().fill(Theme.terracotta.opacity(0.15)).frame(height: 1)
                .padding(.bottom, 6)

            // === VELOCITY MODE ===
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(engine.velocityMode == .full ? Theme.terracotta : Theme.subtle)
                        .frame(width: 7, height: 7)
                        .shadow(color: engine.velocityMode == .full ? Theme.terracotta.opacity(0.4) : .clear, radius: 3)
                    Text("VEL \(engine.velocityMode.rawValue.uppercased())")
                        .font(.system(size: 12, design: .monospaced).bold())
                        .foregroundColor(engine.velocityMode == .full ? Theme.terracotta : Theme.subtle)
                }

                // Metronome
                HStack(spacing: 4) {
                    Circle()
                        .fill(engine.metronome.isOn ? Theme.terracotta : Theme.subtle)
                        .frame(width: 7, height: 7)
                        .shadow(color: engine.metronome.isOn ? Theme.terracotta.opacity(0.4) : .clear, radius: 3)
                    Text("METRO")
                        .font(.system(size: 12, design: .monospaced).bold())
                        .foregroundColor(engine.metronome.isOn ? Theme.terracotta : Theme.subtle)
                }

                // Looper
                if engine.capture.state == .on {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Theme.clay)
                            .frame(width: 7, height: 7)
                            .shadow(color: Theme.clay.opacity(0.4), radius: 3)
                        Text("REC")
                            .font(.system(size: 12, design: .monospaced).bold())
                            .foregroundColor(Theme.clay)
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

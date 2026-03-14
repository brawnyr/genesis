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
        VStack(alignment: .leading, spacing: 10) {

            // === LOOP POSITION — the hero ===
            if engine.transport.isPlaying {
                VStack(alignment: .leading, spacing: 0) {
                    Text(beatPosition)
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.8), radius: 1, x: 0, y: 1)
                        .shadow(color: .white.opacity(0.4), radius: 8)
                        .shadow(color: Theme.orange.opacity(0.3), radius: 20)
                    Text(String(format: "%.1fs", secondsElapsed))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                }
            } else {
                Text("—")
                    .font(.system(size: 48, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.15))
            }

            // === INDICATORS — looper + metronome ===
            HStack(spacing: 16) {
                // Looper — 3-stage pulsing
                if isLooping {
                    LooperIndicator()
                }

                // Metronome
                HStack(spacing: 5) {
                    Circle()
                        .fill(engine.metronome.isOn ? Theme.green : .white.opacity(0.1))
                        .frame(width: 8, height: 8)
                        .shadow(color: engine.metronome.isOn ? Theme.green.opacity(0.8) : .clear, radius: 6)
                    Text("MET")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundColor(engine.metronome.isOn ? Theme.green : .white.opacity(0.25))
                        .shadow(color: engine.metronome.isOn ? Theme.green.opacity(0.5) : .clear, radius: 4)
                }
            }

            // === VOLUME + dB — clean data, no boxes ===
            HStack(spacing: 12) {
                Text("VOL")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(Theme.orange.opacity(0.6))
                Text("\(Int(engine.masterVolume * 100))")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.3), radius: 4)

                Text(formatMasterDb(engine.masterLevelDb))
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(dbColor)
                    .shadow(color: dbColor.opacity(0.5), radius: 6)
                Text("dB")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(dbColor.opacity(0.5))
            }

            // === BPM + BARS — secondary, dim ===
            HStack(spacing: 12) {
                Text("\(engine.transport.bpm)")
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Text("BPM")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.orange.opacity(0.3))
                Text("\(engine.transport.barCount)")
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Text("BAR")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.orange.opacity(0.3))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func formatMasterDb(_ db: Float) -> String {
        if db == -.infinity || db < -60 { return "—" }
        return String(format: "%+.1f", db)
    }
}

// MARK: - Looper 3-stage pulsing indicator

struct LooperIndicator: View {
    @State private var phase: Int = 0

    private let symbols = ["◉", "◎", "●"]
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            Text(symbols[phase])
                .font(.system(size: 16))
                .foregroundColor(Theme.red)
                .shadow(color: Theme.red.opacity(0.9), radius: 4)
                .shadow(color: Theme.red.opacity(0.5), radius: 12)
            Text("REC")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundColor(Theme.red)
                .shadow(color: Theme.red.opacity(0.6), radius: 6)
        }
        .onReceive(timer) { _ in
            phase = (phase + 1) % symbols.count
        }
    }
}

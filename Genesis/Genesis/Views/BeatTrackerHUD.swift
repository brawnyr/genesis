// Genesis/Genesis/Views/BeatTrackerHUD.swift
// Centered floating HUD showing BPM, beat position, and loop state
import SwiftUI

struct BeatTrackerHUD: View {
    @ObservedObject var engine: GenesisEngine

    private var beatPosition: String {
        EngineEventInterpreter.formatBeatPosition(
            framePosition: engine.transport.position,
            loopLengthFrames: engine.transport.loopLengthFrames,
            barCount: engine.transport.barCount
        )
    }

    private var loopSeconds: Double {
        Double(engine.transport.loopLengthFrames) / Transport.sampleRate
    }

    private var elapsedSeconds: Double {
        Double(engine.transport.position) / Transport.sampleRate
    }

    var body: some View {
        HStack(spacing: 20) {
            // BPM
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(engine.transport.bpm)")
                    .font(.system(size: 32, design: .monospaced).bold())
                    .foregroundColor(Theme.text)
                    .shadow(color: Theme.text.opacity(0.3), radius: 4)
                Text("BPM")
                    .font(.system(size: 10, design: .monospaced).bold())
                    .foregroundColor(Theme.terracotta)
            }

            // Divider
            Rectangle()
                .fill(Theme.terracotta.opacity(0.3))
                .frame(width: 1, height: 28)

            // Beat position
            if engine.transport.isPlaying {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(beatPosition)
                        .font(.system(size: 32, design: .monospaced).bold())
                        .foregroundColor(Theme.text)
                        .shadow(color: Theme.text.opacity(0.3), radius: 4)
                    Text("BEAT")
                        .font(.system(size: 10, design: .monospaced).bold())
                        .foregroundColor(Theme.terracotta)
                }
            } else {
                Text("—")
                    .font(.system(size: 32, design: .monospaced).bold())
                    .foregroundColor(Theme.text.opacity(0.2))
            }

            // Divider
            Rectangle()
                .fill(Theme.terracotta.opacity(0.3))
                .frame(width: 1, height: 28)

            // Bars + loop length
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(engine.transport.barCount)")
                    .font(.system(size: 32, design: .monospaced).bold())
                    .foregroundColor(Theme.text)
                    .shadow(color: Theme.text.opacity(0.3), radius: 4)
                VStack(alignment: .leading, spacing: 1) {
                    Text("BAR")
                        .font(.system(size: 10, design: .monospaced).bold())
                        .foregroundColor(Theme.terracotta)
                    Text(String(format: "%.1fs", loopSeconds))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Theme.text.opacity(0.35))
                }
            }

            // Status dots
            HStack(spacing: 6) {
                if engine.transport.isPlaying {
                    Circle()
                        .fill(Theme.forest)
                        .frame(width: 8, height: 8)
                        .shadow(color: Theme.forest.opacity(0.5), radius: 4)
                }
                if engine.capture.state == .on {
                    Circle()
                        .fill(Theme.clay)
                        .frame(width: 8, height: 8)
                        .shadow(color: Theme.clay.opacity(0.5), radius: 4)
                }
                if engine.metronome.isOn {
                    Circle()
                        .fill(Theme.terracotta)
                        .frame(width: 8, height: 8)
                        .shadow(color: Theme.terracotta.opacity(0.4), radius: 4)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.canvasBg.opacity(0.95))
                .shadow(color: Color.black.opacity(0.3), radius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.terracotta.opacity(0.15), lineWidth: 1)
        )
    }
}

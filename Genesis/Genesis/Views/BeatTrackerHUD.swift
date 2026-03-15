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
        HStack(spacing: 28) {
            // BPM
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(engine.transport.bpm)")
                    .font(Theme.hero)
                    .foregroundColor(Theme.chrome)
                    .shadow(color: Theme.chrome.opacity(0.3), radius: 8)
                Text("BPM")
                    .font(Theme.monoSmall.bold())
                    .foregroundColor(Theme.sage)
            }

            // Divider
            Rectangle()
                .fill(Theme.separator)
                .frame(width: 1, height: 36)

            // Beat position
            if engine.transport.isPlaying {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(beatPosition)
                        .font(Theme.hero)
                        .foregroundColor(Theme.chrome)
                        .shadow(color: Theme.chrome.opacity(0.3), radius: 8)
                    Text("BEAT")
                        .font(Theme.monoSmall.bold())
                        .foregroundColor(Theme.sage)
                }
            } else {
                Text("—")
                    .font(Theme.hero)
                    .foregroundColor(Theme.text.opacity(0.15))
            }

            // Divider
            Rectangle()
                .fill(Theme.separator)
                .frame(width: 1, height: 36)

            // Bars + loop length
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(engine.transport.barCount)")
                    .font(Theme.hero)
                    .foregroundColor(Theme.chrome)
                    .shadow(color: Theme.chrome.opacity(0.3), radius: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text("BAR")
                        .font(Theme.monoSmall.bold())
                        .foregroundColor(Theme.sage)
                    Text(String(format: "%.1fs", loopSeconds))
                        .font(Theme.monoTiny)
                        .foregroundColor(Theme.text.opacity(0.3))
                }
            }

            // Status dots
            HStack(spacing: 6) {
                if engine.transport.isPlaying {
                    Circle()
                        .fill(Theme.forest)
                        .frame(width: 10, height: 10)
                        .shadow(color: Theme.forest.opacity(0.5), radius: 5)
                }
                if engine.capture.state == .on {
                    Circle()
                        .fill(Theme.clay)
                        .frame(width: 10, height: 10)
                        .shadow(color: Theme.clay.opacity(0.5), radius: 5)
                }
                if engine.metronome.isOn {
                    Circle()
                        .fill(Theme.terracotta)
                        .frame(width: 10, height: 10)
                        .shadow(color: Theme.terracotta.opacity(0.4), radius: 5)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.canvasBg.opacity(0.95))
                .shadow(color: Color.black.opacity(0.3), radius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.separator, lineWidth: 1)
        )
    }
}

// Genesis/Genesis/Views/BeatTrackerHUD.swift
// Centered floating HUD showing beat position and loop state
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

    var body: some View {
        HStack(spacing: 20) {
            // Beat position
            if engine.transport.isPlaying {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(beatPosition)
                        .font(Theme.hero)
                        .foregroundColor(Theme.chrome)
                        .shadow(color: Theme.electric.opacity(0.25), radius: 8)
                    Text("BEAT")
                        .font(Theme.monoSmall.bold())
                        .foregroundColor(Theme.sage)
                }
            } else {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("—")
                        .font(Theme.hero)
                        .foregroundColor(Theme.text.opacity(0.4))
                    Text(String(format: "%.1fs", loopSeconds))
                        .font(Theme.monoTiny)
                        .foregroundColor(Theme.text.opacity(0.5))
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

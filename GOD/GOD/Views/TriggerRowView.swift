// GOD/GOD/Views/TriggerRowView.swift
import SwiftUI

struct TriggerRowView: View {
    let layer: Layer
    let padName: String
    let loopLength: Int
    let sixteenthLength: Int
    let beatsPerLoop: Int
    let cursorFraction: CGFloat
    let trackWidth: CGFloat
    let nameWidth: CGFloat
    let isActive: Bool

    private var hitColor: Color {
        switch layer.padState {
        case .red: return Theme.red
        case .alive: return Theme.orange
        case .clear: return Theme.ice
        }
    }

    private func hitGlyph(velocity: Int) -> String {
        if velocity >= 100 { return "\u{25C6}" }      // ◆
        if velocity >= 40 { return "\u{25C7}" }        // ◇
        return "\u{00B7}"                               // ·
    }

    private func hitOpacity(velocity: Int) -> Double {
        if velocity >= 100 { return 1.0 }
        if velocity >= 40 { return 0.75 }
        return 0.45
    }

    var body: some View {
        HStack(spacing: 0) {
            // Pad name
            Text(padName.prefix(8).uppercased())
                .font(.system(size: 10, design: .monospaced).bold())
                .foregroundColor(isActive ? Theme.orange : Theme.ice.opacity(0.7))
                .frame(width: nameWidth, alignment: .trailing)
                .padding(.trailing, 4)

            // Track area
            ZStack(alignment: .leading) {
                // Track line
                Rectangle()
                    .fill(Theme.ice.opacity(0.08))
                    .frame(height: 1)
                    .offset(y: 0)

                // Beat markers
                Canvas { context, size in
                    let beatLen = loopLength > 0 && beatsPerLoop > 0
                        ? CGFloat(loopLength) / CGFloat(beatsPerLoop) : 0

                    for beat in 0..<beatsPerLoop {
                        let x = beatLen > 0
                            ? CGFloat(beat) * beatLen / CGFloat(loopLength) * size.width
                            : 0
                        let isBar = beat % Transport.beatsPerBar == 0
                        context.fill(
                            Path(CGRect(x: x, y: 0, width: 1, height: size.height)),
                            with: .color(Theme.ice.opacity(isBar ? 0.2 : 0.08))
                        )
                    }
                }
                .frame(width: trackWidth, height: 20)

                // Hits — positioned Text views (not Canvas, for correct color support)
                ForEach(Array(layer.hits.enumerated()), id: \.offset) { _, hit in
                    let swungFrame = SwingMath.swungPosition(
                        hitFrame: hit.position,
                        swing: layer.swing,
                        sixteenthLength: sixteenthLength,
                        loopLength: loopLength
                    )
                    let xFrac = loopLength > 0 ? CGFloat(swungFrame) / CGFloat(loopLength) : 0
                    let cursorDist = abs(xFrac - cursorFraction)
                    let nearCursor = cursorDist < 0.01
                    let color = nearCursor ? Color.white : hitColor

                    Text(hitGlyph(velocity: hit.velocity))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(color.opacity(hitOpacity(velocity: hit.velocity)))
                        .position(x: xFrac * trackWidth, y: 10)
                }
                .frame(width: trackWidth, height: 20)

                // Playback cursor
                Rectangle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 1.5, height: 20)
                    .offset(x: cursorFraction * trackWidth)
            }
            .frame(width: trackWidth, height: 20)
        }
        .frame(height: 22)
    }
}

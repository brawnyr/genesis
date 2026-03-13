// Genesis/Genesis/Views/TriggerRollView.swift
// Crystal trigger display — pad info + fine-resolution hit visualization
import SwiftUI

struct TriggerRollView: View {
    @ObservedObject var engine: GenesisEngine

    private var loopLen: Int { engine.transport.loopLengthFrames }
    private var cursorFrac: CGFloat {
        guard loopLen > 0 else { return 0 }
        return CGFloat(engine.transport.position) / CGFloat(loopLen)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let blink = Int(timeline.date.timeIntervalSinceReferenceDate / 0.5) % 2 == 0
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let rowH = h / CGFloat(PadBank.padCount)

                ZStack(alignment: .topLeading) {
                    // Void background
                    Color(red: 0.04, green: 0.035, blue: 0.03)

                    // Row separators
                    ForEach(1..<PadBank.padCount, id: \.self) { i in
                        Rectangle()
                            .fill(Color.white.opacity(0.03))
                            .frame(height: 1)
                            .offset(y: CGFloat(i) * rowH)
                    }

                    // Hit dots — crystal points
                    // Snapshot hit data so Canvas redraws when hits change
                    let hitSnapshot = engine.layers.map { $0.hits }
                    let _ = engine.transport.position // also redraw on position change
                    Canvas { ctx, size in
                        for padIdx in 0..<PadBank.padCount {
                            let hits = hitSnapshot[padIdx]
                            let color = Theme.padColor(padIdx)
                            let centerY = CGFloat(padIdx) * rowH + rowH * 0.6

                            for hit in hits {
                                guard loopLen > 0 else { continue }
                                let frac = CGFloat(hit.position) / CGFloat(loopLen)
                                let x = frac * size.width
                                let velNorm = CGFloat(hit.velocity) / 127.0

                                // Outer glow
                                let glowR = 3.0 + velNorm * 4.0
                                let glowRect = CGRect(x: x - glowR, y: centerY - glowR, width: glowR * 2, height: glowR * 2)
                                ctx.fill(
                                    Path(ellipseIn: glowRect),
                                    with: .color(color.opacity(0.15 * Double(velNorm)))
                                )

                                // Core dot
                                let coreR = 1.5 + velNorm * 2.0
                                let coreRect = CGRect(x: x - coreR, y: centerY - coreR, width: coreR * 2, height: coreR * 2)
                                ctx.fill(
                                    Path(ellipseIn: coreRect),
                                    with: .color(color.opacity(0.5 + 0.5 * Double(velNorm)))
                                )
                            }
                        }
                    }

                    // Pad labels + status — top-left of each row
                    ForEach(0..<PadBank.padCount, id: \.self) { padIdx in
                        let layer = engine.layers[padIdx]
                        let isActive = engine.activePadIndex == padIdx
                        let name = PadBank.spliceFolderNames[padIdx].uppercased()

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text(name)
                                    .font(.system(size: 12, design: .monospaced).bold())
                                    .foregroundColor(Theme.red)
                                    .shadow(color: Theme.red.opacity(isActive ? 0.6 : 0.2), radius: 6)
                                Text("\(Int(layer.volume * 100))%")
                                    .font(.system(size: 14, design: .monospaced).bold())
                                    .foregroundColor(layer.isMuted ? Theme.blue : .white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 2)
                                            .stroke((layer.isMuted ? Theme.blue : .white).opacity(0.3), lineWidth: 1)
                                    )
                                    .shadow(color: (layer.isMuted ? Theme.blue : .white).opacity(isActive ? 0.4 : 0.1), radius: 5)
                                Text(layer.statusLine)
                                    .font(.system(size: 14, design: .monospaced).bold())
                                    .foregroundColor(.white.opacity(0.5))
                                    .shadow(color: .white.opacity(0.3), radius: 5)
                                Text("_")
                                    .font(.system(size: 12, weight: .light, design: .monospaced))
                                    .foregroundColor(Theme.red)
                                    .shadow(color: Theme.red.opacity(0.5), radius: 4)
                                    .opacity(isActive && blink ? 0.7 : 0)
                            }
                        }
                        .padding(.leading, 5)
                        .padding(.top, 2)
                        .offset(y: CGFloat(padIdx) * rowH)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            engine.activePadIndex = padIdx
                        }
                    }

                    // Playback cursor — glowing orange line
                    if engine.transport.isPlaying {
                        let cursorX = cursorFrac * w
                        Rectangle()
                            .fill(Theme.orange.opacity(0.8))
                            .frame(width: 1.5, height: h)
                            .shadow(color: Theme.orange.opacity(0.5), radius: 8)
                            .shadow(color: Theme.orange.opacity(0.3), radius: 20)
                            .position(x: cursorX, y: h / 2)
                    }

                }
            }
        }
    }

}

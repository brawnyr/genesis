// Genesis/Genesis/Views/PadSelect.swift
// MGS2-style horizontal cylinder pad selector — spin left/right to select
import SwiftUI

struct PadSelect: View {
    @ObservedObject var engine: GenesisEngine

    // Cylinder geometry
    private let cylinderRadius: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PAD_SELECT")
                .font(.system(size: 11, design: .monospaced).bold())
                .foregroundColor(Theme.terracotta)
                .shadow(color: Theme.terracotta.opacity(0.3), radius: 4)
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 2)

        GeometryReader { geo in
            let centerX = geo.size.width / 2
            let centerY = geo.size.height / 2

            ZStack {
                ForEach(0..<PadBank.padCount, id: \.self) { padIdx in
                    let offset = cylinderOffset(for: padIdx)

                    if offset.depth > -0.15 {
                        let layer = engine.layers[padIdx]
                        let isActive = engine.activePadIndex == padIdx
                        let padColor = Theme.padColor(padIdx)
                        let name = PadBank.spliceFolderNames[padIdx].uppercased()

                        PadCylinderItem(
                            name: name,
                            padColor: padColor,
                            layer: layer,
                            isActive: isActive,
                            depth: offset.depth
                        )
                        .scaleEffect(offset.scale)
                        .opacity(offset.opacity)
                        .offset(x: offset.x)
                        .rotation3DEffect(
                            .degrees(offset.tilt),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.4
                        )
                        .zIndex(offset.depth)
                        .position(x: centerX, y: centerY)
                    }
                }
            }
        }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.72), value: engine.activePadIndex)
    }

    // MARK: - Cylinder math

    private struct CylinderOffset {
        let x: CGFloat
        let scale: CGFloat
        let opacity: Double
        let depth: Double
        let tilt: Double
    }

    private func cylinderOffset(for padIdx: Int) -> CylinderOffset {
        let active = engine.activePadIndex

        var diff = padIdx - active
        let half = PadBank.padCount / 2
        if diff > half { diff -= PadBank.padCount }
        if diff < -half { diff += PadBank.padCount }

        let angleStep = .pi * 2.0 / Double(PadBank.padCount)
        let angle = Double(diff) * angleStep

        // X position — horizontal spin
        let x = CGFloat(sin(angle)) * cylinderRadius

        // Depth: 1 = front center, -1 = back
        let depth = cos(angle)

        // Scale: big at front, shrink into the curve
        let scale = CGFloat(max(0.45 + 0.55 * depth, 0.3))

        // Opacity
        let opacity: Double
        if depth > 0.7 {
            opacity = 1.0
        } else if depth > 0 {
            opacity = depth / 0.7 * 0.8 + 0.15
        } else {
            opacity = max(depth + 0.15, 0) * 0.5
        }

        // Tilt: Y-axis rotation — items turn away as they curve to the sides
        let tilt = Double(diff) * 22.0

        return CylinderOffset(x: x, scale: scale, opacity: opacity, depth: depth, tilt: tilt)
    }
}

// MARK: - Single pad on the cylinder

private struct PadCylinderItem: View {
    let name: String
    let padColor: Color
    let layer: Layer
    let isActive: Bool
    let depth: Double

    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.system(size: isActive ? 28 : 15, design: .monospaced).bold())
                .foregroundColor(padColor)
                .shadow(color: padColor.opacity(isActive ? 0.6 : 0.15), radius: isActive ? 12 : 3)

            if isActive {
                HStack(spacing: 6) {
                    Text("\(Int(layer.volume * 100))%")
                        .font(.system(size: 14, design: .monospaced).bold())
                        .foregroundColor(layer.isMuted ? Theme.moss : Theme.text)

                    if layer.isMuted {
                        Text("MUTE")
                            .font(.system(size: 11, design: .monospaced).bold())
                            .foregroundColor(Theme.clay)
                            .shadow(color: Theme.clay.opacity(0.3), radius: 4)
                    }

                    if !layer.hits.isEmpty {
                        Text("\(layer.hits.count) hits")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(padColor.opacity(0.5))
                    }
                }

                if !layer.statusLine.isEmpty {
                    Text(layer.statusLine)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Theme.text.opacity(0.35))
                        .lineLimit(1)
                }
            }
        }
        .frame(width: 160)
        .padding(.vertical, isActive ? 12 : 6)
    }
}

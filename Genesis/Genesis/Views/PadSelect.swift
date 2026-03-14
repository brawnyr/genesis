// Genesis/Genesis/Views/PadSelect.swift
// MGS2-style horizontal wheel pad selector — all 8 visible, spin to select
import SwiftUI

struct PadSelect: View {
    @ObservedObject var engine: GenesisEngine

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
                let totalWidth = geo.size.width
                let active = engine.activePadIndex

                HStack(spacing: 0) {
                    ForEach(0..<PadBank.padCount, id: \.self) { padIdx in
                        let wheel = wheelWeight(for: padIdx, active: active)
                        let layer = engine.layers[padIdx]
                        let isActive = padIdx == active
                        let padColor = Theme.padColor(padIdx)
                        let name = PadBank.spliceFolderNames[padIdx].uppercased()

                        PadWheelItem(
                            name: name,
                            padColor: padColor,
                            layer: layer,
                            isActive: isActive,
                            wheel: wheel
                        )
                        .frame(width: slotWidth(for: padIdx, active: active, totalWidth: totalWidth))
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            engine.activePadIndex = padIdx
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: engine.activePadIndex)
    }

    // MARK: - Wheel math

    /// 0.0 = far from selected, 1.0 = selected
    private func wheelWeight(for padIdx: Int, active: Int) -> Double {
        var diff = abs(padIdx - active)
        if diff > PadBank.padCount / 2 { diff = PadBank.padCount - diff }
        switch diff {
        case 0: return 1.0
        case 1: return 0.6
        case 2: return 0.35
        case 3: return 0.2
        default: return 0.15
        }
    }

    /// Active pad gets more space, others compress
    private func slotWidth(for padIdx: Int, active: Int, totalWidth: CGFloat) -> CGFloat {
        var diff = abs(padIdx - active)
        if diff > PadBank.padCount / 2 { diff = PadBank.padCount - diff }

        // Weight: active=3.0, adjacent=1.5, others=1.0
        let weight: CGFloat
        switch diff {
        case 0: weight = 3.0
        case 1: weight = 1.5
        default: weight = 1.0
        }

        // Total weights for all 8 pads
        let totalWeight: CGFloat = 3.0 + (1.5 * 2) + (1.0 * 5)
        return totalWidth * weight / totalWeight
    }
}

// MARK: - Single pad on the wheel

private struct PadWheelItem: View {
    let name: String
    let padColor: Color
    let layer: Layer
    let isActive: Bool
    let wheel: Double

    var body: some View {
        VStack(spacing: 4) {
            // Pad name
            Text(name)
                .font(.system(size: isActive ? 24 : max(11, 11 + 6 * wheel), design: .monospaced).bold())
                .foregroundColor(padColor.opacity(0.3 + 0.7 * wheel))
                .shadow(color: padColor.opacity(isActive ? 0.5 : 0.1 * wheel), radius: isActive ? 10 : 3)

            if isActive {
                // Volume
                Text("\(Int(layer.volume * 100))% volume")
                    .font(.system(size: 14, design: .monospaced).bold())
                    .foregroundColor(layer.isMuted ? Theme.moss : Theme.text)

                HStack(spacing: 6) {
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
            } else if wheel > 0.4 {
                // Adjacent pads — show volume small
                Text("\(Int(layer.volume * 100))% volume")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.text.opacity(0.25))
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            isActive
                ? RoundedRectangle(cornerRadius: 4)
                    .fill(padColor.opacity(0.06))
                    .shadow(color: padColor.opacity(0.12), radius: 8)
                : nil
        )
    }
}

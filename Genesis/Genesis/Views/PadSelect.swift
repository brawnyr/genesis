// Genesis/Genesis/Views/PadSelect.swift
// All 8 pads visible with volumes and effects at all times
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
                .padding(.bottom, 4)

            HStack(spacing: 2) {
                ForEach(0..<PadBank.padCount, id: \.self) { padIdx in
                    let layer = engine.layers[padIdx]
                    let isActive = padIdx == engine.activePadIndex
                    let padColor = Theme.padColor(padIdx)
                    let name = PadBank.spliceFolderNames[padIdx].uppercased()

                    PadCell(
                        name: name,
                        padColor: padColor,
                        layer: layer,
                        isActive: isActive,
                        hasSample: engine.padBank.pads[padIdx].sample != nil
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        engine.activePadIndex = padIdx
                    }
                }
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: engine.activePadIndex)
    }
}

// MARK: - Single pad cell — always shows volume + effects

private struct PadCell: View {
    let name: String
    let padColor: Color
    let layer: Layer
    let isActive: Bool
    let hasSample: Bool

    var body: some View {
        VStack(spacing: 3) {
            // Pad name
            Text(name)
                .font(.system(size: isActive ? 16 : 11, design: .monospaced).bold())
                .foregroundColor(layer.isMuted ? Theme.subtle : padColor)
                .shadow(color: isActive ? padColor.opacity(0.5) : .clear, radius: 6)

            // Volume bar
            GeometryReader { geo in
                let barH = geo.size.height
                let fillH = barH * CGFloat(layer.volume)
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.subtle.opacity(0.4))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(layer.isMuted ? Theme.subtle : padColor.opacity(0.6))
                        .frame(height: fillH)
                }
            }
            .frame(width: isActive ? 14 : 8, height: 40)

            // Volume %
            Text("\(Int(layer.volume * 100))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Theme.text.opacity(0.5))

            // Effects indicators
            HStack(spacing: 2) {
                if layer.isMuted {
                    EffectDot(color: Theme.clay, label: "M")
                }
                if layer.choke {
                    EffectDot(color: Theme.wheat, label: "C")
                }
                if layer.looper {
                    EffectDot(color: Theme.forest, label: "L")
                }
            }

            HStack(spacing: 2) {
                if layer.reverbSend > 0.01 {
                    EffectDot(color: Theme.sage, label: "R")
                }
                if layer.swing > 0.51 {
                    EffectDot(color: Theme.moss, label: "S")
                }
                if layer.hpCutoff > 21 || layer.lpCutoff < 19999 {
                    EffectDot(color: Theme.terracotta, label: "F")
                }
            }

            // Hit count
            if !layer.hits.isEmpty {
                Text("\(layer.hits.count)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(padColor.opacity(0.4))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? padColor.opacity(0.08) : Color.clear)
                .shadow(color: isActive ? padColor.opacity(0.15) : .clear, radius: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isActive ? padColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

private struct EffectDot: View {
    let color: Color
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 8, design: .monospaced).bold())
            .foregroundColor(color)
            .frame(width: 12, height: 12)
            .background(Circle().fill(color.opacity(0.15)))
    }
}

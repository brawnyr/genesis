// Genesis/Genesis/Views/PadSelect.swift
// All 8 pads visible — big text, full effect data in columns
import SwiftUI

struct PadSelect: View {
    @ObservedObject var engine: GenesisEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PAD_SELECT")
                .font(Theme.sectionLabel)
                .foregroundColor(Theme.electric)
                .shadow(color: Theme.electric.opacity(0.3), radius: 6)
                .tracking(3)
                .padding(.horizontal, 12)
                .padding(.top, 8)
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
                        isActive: isActive
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

// MARK: - Single pad cell — big name, textual data column

private struct PadCell: View {
    let name: String
    let padColor: Color
    let layer: Layer
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Pad name — big
            Text(name)
                .font(.system(size: 17, design: .monospaced).bold())
                .foregroundColor(layer.isMuted ? Theme.subtle : (isActive ? padColor : padColor.opacity(0.6)))
                .shadow(color: isActive ? padColor.opacity(0.5) : .clear, radius: 6)
                .scaleEffect(isActive ? 1.25 : 1.0)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 2)

            // Data column — textual, always visible
            PadDataRow(label: "vol", value: "\(Int(layer.volume * 100))%", color: padColor, active: true)
            PadDataRow(label: "pan", value: EngineEventInterpreter.formatPan(layer.pan), color: padColor, active: layer.pan != 0.5)

            if layer.isMuted {
                PadDataRow(label: "", value: "MUTE", color: Theme.clay, active: true)
            }
            if layer.choke {
                PadDataRow(label: "", value: "CHOKE", color: Theme.wheat, active: true)
            }
            if layer.looper {
                PadDataRow(label: "", value: "LOOP", color: Theme.forest, active: true)
            }
            if layer.reverbSend > 0.01 {
                PadDataRow(label: "rev", value: "\(Int(layer.reverbSend * 100))%", color: Theme.sage, active: true)
            }
            if layer.swing > 0.51 {
                PadDataRow(label: "sw", value: "\(Int((layer.swing - 0.5) / 0.5 * 100))%", color: Theme.moss, active: true)
            }
            if layer.hpCutoff > 21 {
                PadDataRow(label: "hp", value: EngineEventInterpreter.formatFrequency(layer.hpCutoff), color: Theme.terracotta, active: true)
            }
            if layer.lpCutoff < 19999 {
                PadDataRow(label: "lp", value: EngineEventInterpreter.formatFrequency(layer.lpCutoff), color: Theme.terracotta, active: true)
            }
            if !layer.hits.isEmpty {
                PadDataRow(label: "hits", value: "\(layer.hits.count)", color: padColor.opacity(0.6), active: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? padColor.opacity(0.12) : Color.clear)
                .shadow(color: isActive ? padColor.opacity(0.2) : .clear, radius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isActive ? padColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }
}

private struct PadDataRow: View {
    let label: String
    let value: String
    let color: Color
    let active: Bool

    var body: some View {
        HStack(spacing: 0) {
            if !label.isEmpty {
                Text(label)
                    .foregroundColor(Theme.text.opacity(0.3))
                    .frame(width: 28, alignment: .leading)
            }
            Text(value)
                .foregroundColor(color)
        }
        .font(Theme.mono)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

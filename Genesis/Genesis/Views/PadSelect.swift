// Genesis/Genesis/Views/PadSelect.swift
// All 8 pads visible — big text, full effect data in columns
import SwiftUI

struct PadSelect: View {
    @ObservedObject var engine: GenesisEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: "PAD_SELECT")
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

            HStack(spacing: 2) {
                ForEach(0..<PadBank.padCount, id: \.self) { padIdx in
                    let layer = engine.layers[padIdx]
                    let isActive = padIdx == engine.activePadIndex
                    let padColor = Theme.padColor(padIdx)
                    let name = PadBank.spliceFolderNames[padIdx].uppercased()

                    EquatableView(content: PadCell(
                        name: name,
                        padColor: padColor,
                        layer: layer,
                        isActive: isActive
                    ))
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
// Equatable prevents unnecessary redraws when engine publishes unrelated state at 33Hz.

private struct PadCell: View, Equatable {
    let name: String
    let padColor: Color
    let layer: Layer
    let isActive: Bool

    static func == (lhs: PadCell, rhs: PadCell) -> Bool {
        lhs.name == rhs.name &&
        lhs.padColor == rhs.padColor &&
        lhs.isActive == rhs.isActive &&
        lhs.layer.volume == rhs.layer.volume &&
        lhs.layer.pan == rhs.layer.pan &&
        lhs.layer.isMuted == rhs.layer.isMuted &&
        lhs.layer.choke == rhs.layer.choke &&
        lhs.layer.looper == rhs.layer.looper &&
        lhs.layer.reverbSend == rhs.layer.reverbSend &&
        lhs.layer.swing == rhs.layer.swing &&
        lhs.layer.hpCutoff == rhs.layer.hpCutoff &&
        lhs.layer.lpCutoff == rhs.layer.lpCutoff &&
        lhs.layer.hits.count == rhs.layer.hits.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Pad name — big
            Text(name)
                .font(.system(size: isActive ? 21 : 17, design: .monospaced).bold())
                .foregroundColor(layer.isMuted ? Theme.subtle : (isActive ? padColor : padColor.opacity(0.6)))
                .shadow(color: isActive ? padColor.opacity(0.5) : .clear, radius: 6)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 2)

            // Data column — textual, always visible
            PadDataRow(label: "", value: "vol \(Int(layer.volume * 100))%", color: padColor, active: true)
            PadDataRow(label: "", value: "pan \(EngineEventInterpreter.formatPan(layer.pan))", color: padColor, active: layer.pan != 0.5)

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
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 0)
                .fill(isActive ? padColor.opacity(0.12) : Color.clear)
                .shadow(color: isActive ? padColor.opacity(0.2) : .clear, radius: 8)
        )
        .overlay(
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 0)
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

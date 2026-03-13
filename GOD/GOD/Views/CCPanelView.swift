// GOD/GOD/Views/CCPanelView.swift
import SwiftUI

// MARK: - Inspector helper views

struct InspectorSectionHeader: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text("▶")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.3))
                .tracking(1.5)
        }
    }
}

struct InspectorRow: View {
    let label: String
    let value: String
    let highlight: Bool
    let labelWidth: CGFloat

    init(label: String, value: String, highlight: Bool = false, labelWidth: CGFloat = 50) {
        self.label = label
        self.value = value
        self.highlight = highlight
        self.labelWidth = labelWidth
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .foregroundColor(Color.white.opacity(0.3))
                .frame(width: labelWidth, alignment: .leading)
            Text(value)
                .foregroundColor(highlight ? Theme.orange : Color.white.opacity(0.6))
                .shadow(color: highlight ? Theme.orange.opacity(0.2) : .clear, radius: 4)
        }
        .font(.system(size: 16, design: .monospaced))
        .padding(.vertical, 3)
    }
}

struct TcpsBadge: View {
    let isOn: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("tcps")
                .foregroundColor(Color.white.opacity(0.3))
                .frame(width: 50, alignment: .leading)
            Text(isOn ? "ON" : "OFF")
                .font(.system(size: 15, design: .monospaced).bold())
                .foregroundColor(isOn ? Theme.orange : Color.white.opacity(0.3))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isOn ? Theme.orange.opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(isOn ? Theme.orange.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: isOn ? Theme.orange.opacity(0.3) : .clear, radius: 6)
            Text(isOn ? "(kills previous)" : "(stacks)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.2))
        }
        .font(.system(size: 16, design: .monospaced))
        .padding(.vertical, 3)
    }
}

struct ToggleModeBadge: View {
    let mode: ToggleMode

    private var isNextLoop: Bool { mode == .nextLoop }

    var body: some View {
        HStack(spacing: 8) {
            Text("sync")
                .foregroundColor(Color.white.opacity(0.3))
                .frame(width: 50, alignment: .leading)
            Text(mode.rawValue.uppercased())
                .font(.system(size: 15, design: .monospaced).bold())
                .foregroundColor(isNextLoop ? Theme.blue : Color.white.opacity(0.3))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isNextLoop ? Theme.blue.opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(isNextLoop ? Theme.blue.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: isNextLoop ? Theme.blue.opacity(0.3) : .clear, radius: 6)
        }
        .font(.system(size: 16, design: .monospaced))
        .padding(.vertical, 3)
    }
}

// MARK: - Right-side panel (CC readout + sample browser)

struct CCPanelView: View {
    @ObservedObject var engine: GodEngine
    @Binding var browsingPad: Bool
    @Binding var browserIndex: Int

    private var activeIndex: Int { engine.activePadIndex }
    private var layer: Layer { engine.layers[activeIndex] }
    private var pad: Pad { engine.padBank.pads[activeIndex] }
    private var folderName: String { PadBank.spliceFolderNames[activeIndex] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if browsingPad {
                SampleBrowserView(engine: engine, padIndex: activeIndex, isOpen: $browsingPad, selectedIndex: $browserIndex)
            } else {
                padReadoutView
            }
        }
        .padding(18)
        .frame(width: 260, alignment: .topLeading)
        .background(Color(red: 0.071, green: 0.067, blue: 0.059))
    }

    private var padReadoutView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Channel name — hero
            Text(folderName.uppercased())
                .font(.system(size: 28, design: .monospaced).bold())
                .foregroundColor(layer.isMuted ? Theme.ice : Theme.orange)
                .tracking(2)
                .shadow(color: (layer.isMuted ? Theme.ice : Theme.orange).opacity(0.4), radius: 25)

            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
                .padding(.vertical, 10)

            // SAMPLE section
            InspectorSectionHeader(title: "SAMPLE", color: Theme.blue.opacity(0.5))
                .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 0) {
                if let sample = pad.sample {
                    InspectorRow(label: "file", value: sample.name.lowercased(), labelWidth: 50)
                    InspectorRow(label: "dur", value: String(format: "%.2fs", sample.durationMs / 1000.0), labelWidth: 50)
                    if let bpm = engine.detectedBPMs[activeIndex] {
                        InspectorRow(label: "bpm", value: "\(Int(bpm))", highlight: true, labelWidth: 50)
                    } else {
                        InspectorRow(label: "bpm", value: "--", labelWidth: 50)
                    }
                } else {
                    InspectorRow(label: "file", value: "--", labelWidth: 50)
                }
            }
            .padding(.leading, 16)

            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
                .padding(.vertical, 10)

            // PARAMS section
            InspectorSectionHeader(title: "PARAMS", color: Theme.orange.opacity(0.5))
                .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 0) {
                InspectorRow(label: "vol", value: "\(Int(layer.volume * 100))%")
                InspectorRow(label: "pan", value: EngineEventInterpreter.formatPan(layer.pan))
                InspectorRow(label: "HP", value: EngineEventInterpreter.formatFrequency(layer.hpCutoff),
                             highlight: layer.hpCutoff > 21)
                InspectorRow(label: "LP", value: EngineEventInterpreter.formatFrequency(layer.lpCutoff),
                             highlight: layer.lpCutoff < 19999)
                InspectorRow(label: "swing", value: "\(Int((layer.swing - 0.5) / 0.25 * 100))%",
                             highlight: layer.swing > 0.5, labelWidth: 50)
            }
            .padding(.leading, 16)

            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
                .padding(.vertical, 10)

            // MODE section
            InspectorSectionHeader(title: "MODE", color: Theme.orange.opacity(0.5))
                .padding(.bottom, 6)

            TcpsBadge(isOn: layer.tcps)
                .padding(.leading, 16)

            ToggleModeBadge(mode: engine.toggleMode)
                .padding(.leading, 16)
                .padding(.top, 4)

            Spacer()
        }
    }
}

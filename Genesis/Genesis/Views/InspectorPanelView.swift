// Genesis/Genesis/Views/InspectorPanelView.swift
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
                .shadow(color: color.opacity(0.7), radius: 8)
            Text(title)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white)
                .shadow(color: .white.opacity(0.5), radius: 8)
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
                .foregroundColor(.white)
                .shadow(color: .white.opacity(0.5), radius: 8)
                .frame(width: labelWidth, alignment: .leading)
            Text(value)
                .foregroundColor(highlight ? Theme.orange : .white)
                .shadow(color: highlight ? Theme.orange.opacity(0.6) : .white.opacity(0.5), radius: 8)
        }
        .font(.system(size: 16, design: .monospaced))
        .padding(.vertical, 3)
    }
}

struct ChokeBadge: View {
    let isOn: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("CHOKE")
                .foregroundColor(.white)
                .shadow(color: .white.opacity(0.5), radius: 8)
                .frame(width: 50, alignment: .leading)
            Text(isOn ? "ON" : "OFF")
                .font(.system(size: 15, design: .monospaced).bold())
                .foregroundColor(isOn ? Theme.orange : .white)
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
                .shadow(color: isOn ? Theme.orange.opacity(0.5) : .clear, radius: 8)
            Text(isOn ? "(kills previous)" : "(stacks)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .shadow(color: .white.opacity(0.4), radius: 6)
        }
        .font(.system(size: 16, design: .monospaced))
        .padding(.vertical, 3)
    }
}

struct ToggleModeBadge: View {
    let mode: ToggleMode

    private var isNextLoop: Bool { mode == .nextLoop }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("QUEUED")
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.5), radius: 8)
                    .frame(width: 60, alignment: .leading)
                Text(isNextLoop ? "ON" : "OFF")
                    .font(.system(size: 15, design: .monospaced).bold())
                    .foregroundColor(isNextLoop ? Theme.blue : .white)
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
                    .shadow(color: isNextLoop ? Theme.blue.opacity(0.5) : .clear, radius: 8)
            }
            .font(.system(size: 16, design: .monospaced))

            Text(isNextLoop
                 ? "mutes wait for next loop"
                 : "mutes happen instantly")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .shadow(color: .white.opacity(0.4), radius: 6)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Right-side panel (CC readout + sample browser)

struct InspectorPanelView: View {
    @ObservedObject var engine: GenesisEngine
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
                .foregroundColor(layer.isMuted ? Theme.ice : Theme.red)
                .tracking(2)
                .shadow(color: (layer.isMuted ? Theme.ice : Theme.red).opacity(0.5), radius: 25)

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

            ChokeBadge(isOn: layer.choke)
                .padding(.leading, 16)

            ToggleModeBadge(mode: engine.toggleMode)
                .padding(.leading, 16)
                .padding(.top, 4)

            Spacer()
        }
    }
}

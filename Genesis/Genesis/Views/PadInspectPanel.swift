// Genesis/Genesis/Views/PadInspectPanel.swift
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
                .shadow(color: color.opacity(0.5), radius: 4)
            Text(title)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(Theme.text)
                .shadow(color: Theme.text.opacity(0.3), radius: 4)
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
                .foregroundColor(Theme.text.opacity(0.7))
                .frame(width: labelWidth, alignment: .leading)
            Text(value)
                .foregroundColor(highlight ? Theme.terracotta : Theme.text)
                .shadow(color: highlight ? Theme.terracotta.opacity(0.4) : .clear, radius: 4)
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
                .foregroundColor(Theme.text.opacity(0.7))
                .frame(width: 50, alignment: .leading)
            Text(isOn ? "ON" : "OFF")
                .font(.system(size: 15, design: .monospaced).bold())
                .foregroundColor(isOn ? Theme.terracotta : Theme.text.opacity(0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isOn ? Theme.terracotta.opacity(0.12) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(isOn ? Theme.terracotta.opacity(0.25) : Theme.subtle.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: isOn ? Theme.terracotta.opacity(0.3) : .clear, radius: 4)
            Text(isOn ? "(cuts previous note)" : "(stacks)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Theme.text.opacity(0.5))
        }
        .font(.system(size: 16, design: .monospaced))
        .padding(.vertical, 3)
    }
}


// MARK: - Right-side panel (pad readout + sample browser)

struct PadInspectPanel: View {
    @ObservedObject var engine: GenesisEngine
    @Binding var browsingPad: Bool
    @Binding var browserIndex: Int

    private var activeIndex: Int { engine.activePadIndex }
    private var layer: Layer { engine.layers[activeIndex] }
    private var pad: Pad { engine.padBank.pads[activeIndex] }
    private var folderName: String { PadBank.spliceFolderNames[activeIndex] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("INSPECT")
                .font(.system(size: 11, design: .monospaced).bold())
                .foregroundColor(Theme.terracotta)
                .shadow(color: Theme.terracotta.opacity(0.3), radius: 4)
                .padding(.bottom, 6)

            padReadoutView

            // Integrated sample browser
            if browsingPad {
                Rectangle()
                    .fill(Theme.text.opacity(0.06))
                    .frame(height: 1)
                    .padding(.vertical, 10)

                SampleBrowserView(
                    engine: engine,
                    padIndex: engine.activePadIndex,
                    isOpen: $browsingPad,
                    selectedIndex: $browserIndex
                )
            }

            Spacer()
        }
        .padding(18)
        .frame(width: 260, alignment: .topLeading)
        .frame(maxHeight: .infinity)
        .background(Theme.canvasBg)
    }

    private var padReadoutView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Channel name — hero
            Text(folderName.uppercased())
                .font(.system(size: 28, design: .monospaced).bold())
                .foregroundColor(layer.isMuted ? Theme.moss : Theme.clay)
                .tracking(2)
                .shadow(color: (layer.isMuted ? Theme.moss : Theme.clay).opacity(0.3), radius: 8)

            Rectangle()
                .fill(Theme.text.opacity(0.06))
                .frame(height: 1)
                .padding(.vertical, 10)

            // SAMPLE section
            InspectorSectionHeader(title: "SAMPLE", color: Theme.sage.opacity(0.6))
                .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 0) {
                if let sample = pad.sample {
                    InspectorRow(label: "file", value: sample.name.lowercased(), labelWidth: 50)
                    InspectorRow(label: "dur", value: String(format: "%.2fs", sample.durationMs / 1000.0), labelWidth: 50)
                    let samplePeakDb = sample.peakDb
                    InspectorRow(
                        label: "peak",
                        value: String(format: "%.1fdB", samplePeakDb),
                        highlight: samplePeakDb > -1.0,
                        labelWidth: 50
                    )
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
                .fill(Theme.text.opacity(0.06))
                .frame(height: 1)
                .padding(.vertical, 10)

            // PARAMS section
            InspectorSectionHeader(title: "PARAMS", color: Theme.terracotta.opacity(0.6))
                .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 0) {
                InspectorRow(label: "pan", value: EngineEventInterpreter.formatPan(layer.pan))
                InspectorRow(label: "HP", value: EngineEventInterpreter.formatFrequency(layer.hpCutoff),
                             highlight: layer.hpCutoff > 21)
                InspectorRow(label: "LP", value: EngineEventInterpreter.formatFrequency(layer.lpCutoff),
                             highlight: layer.lpCutoff < 19999)
                InspectorRow(label: "rev", value: "\(Int(layer.reverbSend * 100))%",
                             highlight: layer.reverbSend > 0.01, labelWidth: 60)
                InspectorRow(label: "swing", value: "\(Int((layer.swing - 0.5) / 0.5 * 100))%",
                             highlight: layer.swing > 0.5, labelWidth: 60)
            }
            .padding(.leading, 16)

            Rectangle()
                .fill(Theme.text.opacity(0.06))
                .frame(height: 1)
                .padding(.vertical, 10)

            // MODE section
            InspectorSectionHeader(title: "MODE", color: Theme.terracotta.opacity(0.6))
                .padding(.bottom, 6)

            ChokeBadge(isOn: layer.choke)
                .padding(.leading, 16)
        }
    }
}

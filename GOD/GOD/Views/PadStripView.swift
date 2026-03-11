// GOD/GOD/Views/PadStripView.swift
import SwiftUI

struct PadStripView: View {
    @ObservedObject var engine: GodEngine
    @ObservedObject var interpreter: EngineEventInterpreter

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<8, id: \.self) { index in
                PadView(
                    index: index,
                    pad: engine.padBank.pads[index],
                    layer: engine.layers[index],
                    isActive: engine.activePadIndex == index,
                    triggered: engine.channelTriggered[index],
                    signalLevel: engine.channelSignalLevels[index],
                    intensity: interpreter.padIntensities[index]
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

struct PadView: View {
    let index: Int
    let pad: Pad
    let layer: Layer
    let isActive: Bool
    let triggered: Bool
    let signalLevel: Float
    let intensity: Float

    private var borderColor: Color {
        if layer.isMuted { return Theme.subtle }
        if intensity > 0.5 && (pad.sample?.durationMs ?? 0) > 1000 { return Theme.orange }
        return Theme.blue
    }

    var body: some View {
        VStack(spacing: 3) {
            // Pad number
            Text("\(index + 1)")
                .font(.system(size: 14, design: .monospaced).bold())
                .foregroundColor(triggered ? Theme.orange : (isActive ? Theme.blue : Theme.subtle))

            // Sample name
            Text(pad.sample?.name.uppercased().prefix(6) ?? "—")
                .font(Theme.monoTiny)
                .foregroundColor(layer.isMuted ? Theme.subtle : Color(white: 0.7))
                .lineLimit(1)

            // Signal meter
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Theme.subtle.opacity(0.3))
                    RoundedRectangle(cornerRadius: 1)
                        .fill(borderColor)
                        .frame(width: geo.size.width * CGFloat(signalLevel))
                }
            }
            .frame(height: 3)

            // CC values on active pad
            if isActive {
                VStack(spacing: 1) {
                    CCLabel(name: "vol", value: "\(Int(layer.volume * 100))%", highlight: false)
                    CCLabel(name: "pan", value: EngineEventInterpreter.formatPan(layer.pan), highlight: false)
                    CCLabel(name: "HP", value: EngineEventInterpreter.formatFrequency(layer.hpCutoff),
                            highlight: layer.hpCutoff > 21)
                    CCLabel(name: "LP", value: EngineEventInterpreter.formatFrequency(layer.lpCutoff),
                            highlight: layer.lpCutoff < 19999)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .layoutPriority(isActive ? 1.4 : 1.0)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(layer.isMuted
                      ? Color(red: 0.118, green: 0.114, blue: 0.102)
                      : Color(red: 0.145, green: 0.137, blue: 0.125))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.orange.opacity(triggered ? 0.15 : 0))
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(borderColor)
                .frame(height: 2)
        }
        .shadow(color: isActive ? Theme.blue.opacity(0.25) : .clear, radius: 8)
        .opacity(layer.isMuted ? 0.5 : 1.0)
    }
}

struct CCLabel: View {
    let name: String
    let value: String
    let highlight: Bool

    var body: some View {
        HStack(spacing: 2) {
            Text(name)
                .foregroundColor(Theme.subtle)
            Text(value)
                .foregroundColor(highlight ? Theme.orange : Color(white: 0.7))
        }
        .font(.system(size: 7, design: .monospaced))
    }
}

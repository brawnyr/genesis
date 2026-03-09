import SwiftUI

struct ChannelListView: View {
    @ObservedObject var engine: GodEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<8, id: \.self) { i in
                ChannelRowView(
                    index: i,
                    layer: engine.layers[i],
                    pad: engine.padBank.pads[i],
                    signalLevel: engine.channelSignalLevels[i],
                    triggered: engine.channelTriggered[i]
                )
            }
        }
    }
}

struct ChannelRowView: View {
    let index: Int
    let layer: Layer
    let pad: Pad
    let signalLevel: Float
    let triggered: Bool

    private var hasContent: Bool {
        pad.sample != nil || !layer.hits.isEmpty
    }

    private var displayName: String {
        if pad.sample != nil { return pad.name }
        if !layer.hits.isEmpty { return layer.name }
        return "—"
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .foregroundColor(Theme.text)
                .frame(width: 16, alignment: .trailing)

            Text(displayName)
                .foregroundColor(Theme.text)
                .frame(width: 80, alignment: .leading)

            if hasContent {
                Text(layer.isMuted ? "○" : "●")
                    .foregroundColor(layer.isMuted ? Theme.text : Theme.blue)
            }

            if hasContent && !layer.isMuted {
                SignalMeterView(level: signalLevel)
            }

            Spacer()
        }
        .font(Theme.mono)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(triggered ? Theme.text.opacity(0.15) : Color.clear)
        .animation(.easeOut(duration: 0.08), value: triggered)
    }
}

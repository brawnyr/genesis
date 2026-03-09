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
            // Channel number — lights up orange on trigger
            Text("\(index + 1)")
                .foregroundColor(triggered ? Theme.orange : Theme.text)
                .frame(width: 20, alignment: .trailing)

            // Sample name
            Text(displayName)
                .foregroundColor(triggered ? Theme.orange : Theme.text)
                .frame(width: 100, alignment: .leading)

            // Active/muted indicator
            if hasContent {
                Text(layer.isMuted ? "○" : "●")
                    .foregroundColor(layer.isMuted ? Theme.text : Theme.blue)
            }

            // Signal meter
            if hasContent && !layer.isMuted {
                SignalMeterView(level: signalLevel)
            }

            Spacer()
        }
        .font(Theme.mono)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(triggered ? Theme.orange.opacity(0.2) : Color.clear)
        )
        .animation(.easeOut(duration: 0.1), value: triggered)
    }
}

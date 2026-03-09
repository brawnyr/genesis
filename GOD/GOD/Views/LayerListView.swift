import SwiftUI

struct LayerListView: View {
    @ObservedObject var engine: GodEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(engine.layers.indices, id: \.self) { i in
                let layer = engine.layers[i]
                if !layer.hits.isEmpty || engine.padBank.pads[i].sample != nil {
                    LayerRow(
                        layer: layer,
                        loopLength: engine.transport.loopLengthFrames
                    )
                }
            }
        }
    }
}

struct LayerRow: View {
    let layer: Layer
    let loopLength: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("\(layer.index + 1)")
                .foregroundColor(Theme.dim)
                .frame(width: 16, alignment: .trailing)

            Text(layer.name)
                .foregroundColor(layer.isMuted ? Theme.muted : Theme.text)
                .frame(width: 50, alignment: .leading)

            Text(layer.isMuted ? "■" : "▶")
                .foregroundColor(layer.isMuted ? Theme.muted : Theme.green)

            HitPatternView(hits: layer.hits, loopLength: loopLength)
                .opacity(layer.isMuted ? 0.3 : 1.0)
        }
        .font(Theme.monoSmall)
    }
}

struct HitPatternView: View {
    let hits: [Hit]
    let loopLength: Int
    private let resolution = 32

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<resolution, id: \.self) { slot in
                let slotStart = loopLength > 0 ? loopLength * slot / resolution : 0
                let slotEnd = loopLength > 0 ? loopLength * (slot + 1) / resolution : 0
                let hasHit = hits.contains { $0.position >= slotStart && $0.position < slotEnd }
                Text(hasHit ? "●" : "·")
                    .foregroundColor(hasHit ? Theme.accent : Theme.muted)
            }
        }
        .font(.system(size: 8, design: .monospaced))
    }
}

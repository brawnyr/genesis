// GOD/GOD/Views/TriggerMatrixView.swift
import SwiftUI

struct TriggerMatrixView: View {
    @ObservedObject var engine: GodEngine

    /// Pads that should show rows: have hits or are armed (red)
    private var visibleLayers: [(index: Int, layer: Layer)] {
        engine.layers.enumerated().compactMap { i, layer in
            if !layer.hits.isEmpty || layer.padState == .red {
                return (index: i, layer: layer)
            }
            return nil
        }
    }

    var body: some View {
        GeometryReader { geo in
            let loopLen = engine.transport.loopLengthFrames
            let beatsPerLoop = engine.transport.barCount * Transport.beatsPerBar
            let sixteenthLen = SwingMath.sixteenthLength(loopLengthFrames: loopLen, beatsPerLoop: beatsPerLoop)
            let cursorFrac = loopLen > 0 ? CGFloat(engine.transport.position) / CGFloat(loopLen) : 0
            let nameWidth: CGFloat = 72
            let trackWidth = geo.size.width - nameWidth - 16  // 8px padding each side

            if visibleLayers.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(visibleLayers, id: \.index) { item in
                        TriggerRowView(
                            layer: item.layer,
                            padName: engine.padBank.pads[item.index].name,
                            loopLength: loopLen,
                            sixteenthLength: sixteenthLen,
                            beatsPerLoop: beatsPerLoop,
                            cursorFraction: cursorFrac,
                            trackWidth: trackWidth,
                            nameWidth: nameWidth,
                            isActive: item.index == engine.activePadIndex
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(.horizontal, 8)
                .animation(.easeInOut(duration: 0.3), value: visibleLayers.map(\.index))
            }
        }
    }
}

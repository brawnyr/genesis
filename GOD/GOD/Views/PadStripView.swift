// GOD/GOD/Views/PadStripView.swift
import SwiftUI

struct PadStripView: View {
    @ObservedObject var engine: GodEngine
    @ObservedObject var interpreter: EngineEventInterpreter

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<PadBank.padCount, id: \.self) { index in
                PadCell(
                    index: index,
                    pad: engine.padBank.pads[index],
                    layer: engine.layers[index],
                    isActive: engine.activePadIndex == index,
                    triggered: engine.channelTriggered[index],
                    signalLevel: engine.channelSignalLevels[index],
                    intensity: interpreter.padIntensities[index],
                    folderName: PadBank.spliceFolderNames[index],
                    pendingMute: engine.pendingMutes[index]
                )
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }
}

// MARK: - Loop progress bar (above pads)

struct LoopProgressBar: View {
    @ObservedObject var engine: GodEngine

    private var progress: Double {
        let loopLen = engine.transport.loopLengthFrames
        guard loopLen > 0 else { return 0 }
        return Double(engine.transport.position) / Double(loopLen)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.subtle.opacity(0.15))
                Rectangle()
                    .fill(engine.transport.isPlaying ? Theme.blue : Theme.subtle.opacity(0.3))
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 6)
        .padding(.horizontal, 6)
    }
}

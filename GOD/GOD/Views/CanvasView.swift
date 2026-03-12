// GOD/GOD/Views/CanvasView.swift
import SwiftUI

struct CanvasView: View {
    @ObservedObject var engine: GodEngine
    @ObservedObject var interpreter: EngineEventInterpreter

    var body: some View {
        ZStack {
            Theme.canvasBg

            // Layer 1: Pad visual columns (background)
            PadVisualsLayer(
                interpreter: interpreter,
                isMuted: engine.layers.map(\.isMuted),
                isSustained: (0..<PadBank.padCount).map { i in
                    (engine.padBank.pads[i].sample?.durationMs ?? 0) > engine.loopDurationMs
                }
            )

            // Layer 2: GOD title + transport (middle)
            GodTitleLayer(
                isPlaying: engine.transport.isPlaying,
                capture: engine.capture,
                transport: engine.transport,
                metronome: engine.metronome,
                masterVolume: engine.masterVolume
            )

            // Layer 3: Terminal text (foreground, always visible)
            TerminalTextLayer(interpreter: interpreter)
        }
    }
}

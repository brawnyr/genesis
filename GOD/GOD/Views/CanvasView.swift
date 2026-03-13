// GOD/GOD/Views/CanvasView.swift
import SwiftUI

struct CanvasView: View {
    @ObservedObject var engine: GodEngine
    @ObservedObject var interpreter: EngineEventInterpreter

    private var hasActiveRows: Bool {
        engine.layers.contains { !$0.hits.isEmpty || $0.padState == .red }
    }

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

            if hasActiveRows {
                // Compact layout: title top, trigger matrix middle, terminal bottom
                VStack(spacing: 0) {
                    // GOD title (compact)
                    GodTitleLayer(
                        isPlaying: engine.transport.isPlaying,
                        capture: engine.capture,
                        transport: engine.transport,
                        metronome: engine.metronome,
                        masterVolume: engine.masterVolume
                    )
                    .frame(maxHeight: 200)

                    // Trigger matrix
                    TriggerMatrixView(engine: engine)
                        .frame(maxHeight: .infinity)

                    // Terminal log
                    TerminalTextLayer(interpreter: interpreter)
                        .frame(maxHeight: 160)
                }
            } else {
                // Full layout: title + geometry fill canvas, terminal overlaid
                GodTitleLayer(
                    isPlaying: engine.transport.isPlaying,
                    capture: engine.capture,
                    transport: engine.transport,
                    metronome: engine.metronome,
                    masterVolume: engine.masterVolume
                )

                TerminalTextLayer(interpreter: interpreter)
            }
        }
    }
}

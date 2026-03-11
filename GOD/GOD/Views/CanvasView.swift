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
                isSustained: (0..<8).map { i in
                    (engine.padBank.pads[i].sample?.durationMs ?? 0) > engine.loopDurationMs
                }
            )

            // Layer 2: ASCII GOD title (middle)
            GodTitleLayer(isPlaying: engine.transport.isPlaying)

            // Layer 3: Terminal text (foreground)
            if engine.transport.isPlaying {
                TerminalTextLayer(interpreter: interpreter)
            }
        }
    }
}

// MARK: - Visual columns rising from pads

struct PadVisualsLayer: View {
    @ObservedObject var interpreter: EngineEventInterpreter
    let isMuted: [Bool]
    let isSustained: [Bool]

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { i in
                    ZStack(alignment: .bottom) {
                        if !isMuted[i] && interpreter.padIntensities[i] > 0.01 {
                            let intensity = CGFloat(interpreter.padIntensities[i])
                            let height = geo.size.height * intensity
                            let color = isSustained[i] ? Theme.orange : Theme.blue

                            LinearGradient(
                                gradient: Gradient(colors: [
                                    color.opacity(Double(intensity) * 0.2),
                                    color.opacity(0.03),
                                    .clear
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                            .frame(height: height)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }
}

// MARK: - ASCII GOD title

struct GodTitleLayer: View {
    let isPlaying: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(Theme.godArtIdle)
                .font(.system(size: 12, design: .monospaced).bold())
                .foregroundColor(isPlaying ? Theme.blue : Theme.charcoal)
                .shadow(color: isPlaying ? Theme.blue.opacity(0.4) : .clear, radius: 20)
                .multilineTextAlignment(.center)

            if !isPlaying {
                Text(Theme.godSubtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.charcoal)
                    .tracking(4)

                Text("press SPACE to begin")
                    .font(Theme.monoTiny)
                    .foregroundColor(Theme.charcoal.opacity(0.6))
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - Terminal text overlay

struct TerminalTextLayer: View {
    @ObservedObject var interpreter: EngineEventInterpreter

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    Spacer(minLength: 100)

                    ForEach(Array(interpreter.lines.enumerated()), id: \.element.id) { index, line in
                        Text(line.text)
                            .font(Theme.monoTiny)
                            .foregroundColor(Theme.text)
                            .opacity(lineOpacity(index: index, total: interpreter.lines.count))
                            .id(line.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .onChange(of: interpreter.lines.count) { _, _ in
                if let last = interpreter.lines.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func lineOpacity(index: Int, total: Int) -> Double {
        guard total > 1 else { return 1.0 }
        let position = Double(index) / Double(total - 1)
        return 0.3 + 0.7 * position
    }
}

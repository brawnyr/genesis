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

            // Layer 2: GOD title + transport (middle)
            GodTitleLayer(
                isPlaying: engine.transport.isPlaying,
                capture: engine.capture,
                transport: engine.transport,
                metronome: engine.metronome
            )

            // Layer 3: Terminal text (foreground, always visible)
            TerminalTextLayer(interpreter: interpreter)
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
                            // Hot pads = orange columns
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Theme.orange.opacity(Double(intensity) * 0.25),
                                    Theme.orange.opacity(0.03),
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

// MARK: - GOD title — generative pixel field with animated text

struct GodTitleLayer: View {
    let isPlaying: Bool
    let capture: GodCapture
    let transport: Transport
    let metronome: Metronome

    @State private var phase: Double = 0
    @State private var ambientPixels: [DriftPixel] = GodTitleLayer.generatePixels(count: 40)

    private static let godBitmap = Theme.godBitmap

    private var isGodMode: Bool {
        capture.state == .armed || capture.state == .recording
    }

    private var currentBeat: Int {
        let beatLength = metronome.beatLengthFrames(bpm: transport.bpm, sampleRate: Transport.sampleRate)
        guard beatLength > 0 else { return 1 }
        return (transport.position / beatLength) % (transport.barCount * 4) + 1
    }

    private static func generatePixels(count: Int) -> [DriftPixel] {
        (0..<count).map { _ in
            DriftPixel(
                x: Double.random(in: -180...180),
                y: Double.random(in: -70...70),
                size: Double.random(in: 1.5...3.5),
                speed: Double.random(in: 0.3...1.2),
                phaseOffset: Double.random(in: 0...(.pi * 2)),
                drift: Double.random(in: 0.2...0.8),
                brightness: Double.random(in: 0.15...0.5)
            )
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Pixel-rendered GOD + ambient swirl
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let cx = size.width / 2
                    let cy = size.height / 2

                    // --- Ambient swirl pixels behind ---
                    for px in ambientPixels {
                        let angle = t * px.speed * 0.6 + px.phaseOffset
                        let r = 15.0 + px.drift * 35.0 + sin(t * px.speed * 0.3 + px.phaseOffset) * 12
                        let x = cx + px.x * 0.6 + cos(angle) * r
                        let y = cy + px.y * 0.5 + sin(angle) * r * 0.6
                        let pulse = 0.5 + 0.5 * sin(t * px.speed * 1.5 + px.phaseOffset)
                        let alpha: Double
                        let color: Color
                        if isGodMode {
                            alpha = px.brightness * (0.4 + 0.4 * pulse)
                            color = px.phaseOffset > .pi * 1.3 ? Color.red : Theme.orange
                        } else if isPlaying {
                            alpha = px.brightness * (0.3 + 0.4 * pulse)
                            color = px.phaseOffset > .pi ? Theme.orange : Color.white.opacity(0.6)
                        } else {
                            alpha = px.brightness * (0.2 + 0.35 * pulse)
                            color = px.phaseOffset > .pi ? Theme.ice : Color.white.opacity(0.4)
                        }
                        context.fill(
                            Path(CGRect(x: x, y: y, width: px.size, height: px.size)),
                            with: .color(color.opacity(alpha))
                        )
                    }

                    // --- GOD letters as animated pixel grid ---
                    let pixelSize: Double = 4.5
                    let gap: Double = 1.5
                    let cellSize = pixelSize + gap
                    let letterW = 7.0 * cellSize
                    let letterSpacing: Double = 18.0
                    let totalW = 3.0 * letterW + 2.0 * letterSpacing
                    let totalH = 9.0 * cellSize
                    let startX = cx - totalW / 2
                    let startY = cy - totalH / 2

                    for (li, letter) in Self.godBitmap.enumerated() {
                        let lx = startX + Double(li) * (letterW + letterSpacing)
                        for (row, bits) in letter.enumerated() {
                            for (col, on) in bits.enumerated() {
                                guard on else { continue }
                                let baseX = lx + Double(col) * cellSize
                                let baseY = startY + Double(row) * cellSize

                                // Each pixel has its own phase based on position
                                let seed = Double(li * 100 + row * 10 + col)
                                let drift = sin(t * 1.8 + seed * 0.7) * 1.2
                                let driftY = cos(t * 1.3 + seed * 0.9) * 0.8
                                let pulse = 0.7 + 0.3 * sin(t * 2.5 + seed * 0.5)
                                let flicker = 0.85 + 0.15 * sin(t * 11 + seed) * sin(t * 7 + seed * 1.3)

                                let x = baseX + drift
                                let y = baseY + driftY
                                let alpha = pulse * flicker

                                if isGodMode {
                                    // Hot orange with red shimmer
                                    let isEmber = sin(seed * 2.3 + t * 0.8) > 0.3
                                    context.fill(
                                        Path(CGRect(x: x, y: y, width: pixelSize, height: pixelSize)),
                                        with: .color((isEmber ? Color.red : Theme.orange).opacity(alpha))
                                    )
                                } else if isPlaying {
                                    // Warm orange
                                    context.fill(
                                        Path(CGRect(x: x, y: y, width: pixelSize, height: pixelSize)),
                                        with: .color(Theme.orange.opacity(alpha))
                                    )
                                } else {
                                    // Icy white — sharp, cold, electric
                                    let iceBlend = sin(seed * 1.7 + t * 1.2) > 0.2
                                    context.fill(
                                        Path(CGRect(x: x, y: y, width: pixelSize, height: pixelSize)),
                                        with: .color((iceBlend ? Color.white : Theme.ice).opacity(alpha))
                                    )
                                }
                            }
                        }
                    }

                    // --- Underline ---
                    let ulY = startY + totalH + 8
                    let ulW: Double = 160
                    let ulX = cx - ulW / 2
                    let ulAlpha = 0.3 + 0.2 * sin(t * 0.8)
                    let ulColor = isGodMode ? Theme.orange : (isPlaying ? Theme.orange : Theme.ice)
                    // Faded gradient via 3 rects
                    for i in 0..<Int(ulW / 2) {
                        let frac = Double(i) / (ulW / 2)
                        let fade = frac < 0.5 ? frac * 2 : (1 - frac) * 2
                        context.fill(
                            Path(CGRect(x: ulX + Double(i) * 2, y: ulY, width: 2, height: 1.5)),
                            with: .color(ulColor.opacity(ulAlpha * fade))
                        )
                    }
                }
                .frame(width: 380, height: 140)
            }
            .allowsHitTesting(false)

            // Status text
            if isPlaying {
                if isGodMode {
                    Text("GENESIS ON DISK")
                        .font(.system(size: 11, design: .monospaced).bold())
                        .foregroundColor(Theme.orange)
                        .tracking(4)
                        .shadow(color: Theme.orange.opacity(0.7), radius: 12)

                    if capture.state == .recording {
                        Text("recording")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Theme.orange)
                            .opacity(0.5 + 0.5 * sin(phase * 2))
                            .padding(.top, 2)
                    } else {
                        Text("armed — next loop boundary")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Theme.orange)
                            .padding(.top, 2)
                    }
                }
            } else {
                Text("[space]")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.2))
            }

            // Transport info
            HStack(spacing: 16) {
                Text("\(transport.bpm)")
                    .foregroundColor(.white)
                    .font(.system(size: 20, design: .monospaced).bold())
                + Text(" bpm")
                    .foregroundColor(Theme.orange.opacity(0.7))
                    .font(.system(size: 16, design: .monospaced))

                Text("\(transport.barCount) bars")
                    .foregroundColor(.white)
                    .font(.system(size: 16, design: .monospaced).bold())

                Text(metronome.isOn ? "metro on" : "metro off")
                    .foregroundColor(metronome.isOn ? Theme.orange : Theme.subtle)
                    .font(.system(size: 16, design: .monospaced))

                if isPlaying {
                    Text("beat \(currentBeat)")
                        .foregroundColor(Theme.orange)
                        .font(.system(size: 16, design: .monospaced))
                }
            }
            .padding(.top, 8)
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Pixel data for drift field

struct DriftPixel {
    let x: Double
    let y: Double
    let size: Double
    let speed: Double
    let phaseOffset: Double
    let drift: Double
    let brightness: Double
}

// MARK: - Terminal text overlay

struct TerminalTextLayer: View {
    @ObservedObject var interpreter: EngineEventInterpreter
    @State private var cursorVisible = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 1) {
                    Spacer(minLength: 100)

                    ForEach(Array(interpreter.lines.enumerated()), id: \.element.id) { index, line in
                        HStack(alignment: .top, spacing: 0) {
                            Text(line.timeString)
                                .foregroundColor(Color(white: 0.3))
                            Text(" > ")
                                .foregroundColor(lineColor(line.kind).opacity(0.5))
                            Text(line.text)
                                .foregroundColor(lineColor(line.kind))
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .opacity(lineOpacity(index: index, total: interpreter.lines.count))
                        .id(line.id)
                    }

                    // Blinking cursor
                    Text("_")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.orange)
                        .opacity(cursorVisible ? 0.7 : 0)
                        .id("cursor")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .onChange(of: interpreter.lines.count) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("cursor", anchor: .bottom)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                cursorVisible.toggle()
            }
        }
    }

    private func lineColor(_ kind: LineKind) -> Color {
        switch kind {
        case .system:    return Color(white: 0.5)
        case .transport: return Theme.blue
        case .hit:       return Theme.orange
        case .state:     return Color(white: 0.75)
        case .capture:   return Theme.orange
        case .browse:    return Theme.ice
        }
    }

    private func lineOpacity(index: Int, total: Int) -> Double {
        guard total > 1 else { return 1.0 }
        let position = Double(index) / Double(total - 1)
        return 0.35 + 0.65 * position
    }
}

// GOD/GOD/Views/GodTitleLayer.swift
import SwiftUI

enum GeoShapeKind: CaseIterable {
    case triangle, hexagon, line, angularSpiral, fragment
}

struct GeoShape {
    let kind: GeoShapeKind
    let cx: Double              // center X offset from canvas center
    let cy: Double              // center Y offset from canvas center
    let size: Double            // bounding size
    let rotation: Double        // initial rotation (radians)
    let rotationSpeed: Double   // radians per second
    let baseOpacity: Double     // depth layering
    let jitter: Double          // CRT vibration amplitude
    let lifespan: Double        // seconds before respawn
    let birthTime: Double
    let mirror: Bool
    let seed: Double            // unique per shape for deterministic noise
}

struct GodTitleLayer: View {
    let isPlaying: Bool
    let capture: GodCapture
    let transport: Transport
    let metronome: Metronome
    let masterVolume: Float

    @State private var phase: Double = 0
    @State private var shapes: [GeoShape] = []
    @State private var lastSpawnTime: Double = 0

    private var isGodMode: Bool {
        capture.state == .armed || capture.state == .recording
    }

    private var shapeCount: Int {
        isGodMode ? 40 : (isPlaying ? 35 : 25)
    }

    private var speedMultiplier: Double {
        isGodMode ? 2.5 : (isPlaying ? 1.5 : 0.7)
    }

    private var jitterMultiplier: Double {
        isGodMode ? 3.0 : (isPlaying ? 1.5 : 0.5)
    }

    private var baseAlphaMultiplier: Double {
        isGodMode ? 0.8 : (isPlaying ? 0.6 : 0.4)
    }

    private static func spawnShape(at t: Double) -> GeoShape {
        // Gaussian-ish distribution: sum of randoms clusters toward center
        let rx = (Double.random(in: -1...1) + Double.random(in: -1...1)) * 0.5
        let ry = (Double.random(in: -1...1) + Double.random(in: -1...1)) * 0.5
        return GeoShape(
            kind: GeoShapeKind.allCases.randomElement()!,
            cx: rx * 150,
            cy: ry * 55,
            size: Double.random(in: 8...50),
            rotation: Double.random(in: 0...(.pi * 2)),
            rotationSpeed: Double.random(in: -2.0...2.0),
            baseOpacity: Double.random(in: 0.15...0.7),
            jitter: Double.random(in: 0...2.5),
            lifespan: Double.random(in: 1.5...5.0),
            birthTime: t + Double.random(in: -0.5...0),
            mirror: Bool.random(),
            seed: Double.random(in: 0...1000)
        )
    }

    private static func buildPath(kind: GeoShapeKind, size: Double, seed: Double) -> Path {
        var path = Path()
        switch kind {
        case .triangle:
            let r = size / 2
            // Slightly irregular triangle
            let wobble = seed.truncatingRemainder(dividingBy: 1.0) * 0.3
            for i in 0..<3 {
                let angle = (Double(i) / 3.0) * .pi * 2 - .pi / 2 + wobble * sin(Double(i) * 2.1)
                let px = cos(angle) * r
                let py = sin(angle) * r
                if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
                else { path.addLine(to: CGPoint(x: px, y: py)) }
            }
            path.closeSubpath()

        case .hexagon:
            let r = size / 2
            for i in 0..<6 {
                let angle = (Double(i) / 6.0) * .pi * 2
                let px = cos(angle) * r
                let py = sin(angle) * r
                if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
                else { path.addLine(to: CGPoint(x: px, y: py)) }
            }
            path.closeSubpath()

        case .line:
            let halfLen = size / 2
            let angle = seed * 0.1
            path.move(to: CGPoint(x: -cos(angle) * halfLen, y: -sin(angle) * halfLen))
            path.addLine(to: CGPoint(x: cos(angle) * halfLen, y: sin(angle) * halfLen))

        case .angularSpiral:
            // Sharp-cornered spiral outward
            let segments = 8
            var x = 0.0, y = 0.0
            let step = size / Double(segments)
            path.move(to: CGPoint(x: x, y: y))
            for i in 0..<segments {
                let angle = Double(i) * 0.9 + seed * 0.05
                x += cos(angle) * step * (1 + Double(i) * 0.15)
                y += sin(angle) * step * (1 + Double(i) * 0.15)
                path.addLine(to: CGPoint(x: x, y: y))
            }

        case .fragment:
            // Irregular shard — 3-5 vertices
            let verts = 3 + Int(seed.truncatingRemainder(dividingBy: 3))
            let r = size / 2
            for i in 0..<verts {
                let frac = Double(i) / Double(verts)
                let angle = frac * .pi * 2 + sin(seed + Double(i)) * 0.4
                let dist = r * (0.5 + 0.5 * abs(sin(seed * 3 + Double(i) * 1.7)))
                let px = cos(angle) * dist
                let py = sin(angle) * dist
                if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
                else { path.addLine(to: CGPoint(x: px, y: py)) }
            }
            path.closeSubpath()
        }
        return path
    }

    var body: some View {
        VStack(spacing: 12) {
            // Generative geometric field
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let centerX = size.width / 2
                    let centerY = size.height / 2

                    for shape in shapes {
                        let age = t - shape.birthTime
                        guard age > 0 else { continue }
                        guard age < shape.lifespan else { continue }

                        // Fade in/out
                        let fadeIn = min(age / 0.3, 1.0)
                        let fadeOut = min((shape.lifespan - age) / 0.3, 1.0)
                        let fade = fadeIn * fadeOut

                        // Rotation
                        let rot = shape.rotation + age * shape.rotationSpeed * speedMultiplier

                        // CRT jitter
                        let jx = sin(t * 47 + shape.seed) * shape.jitter * jitterMultiplier
                        let jy = cos(t * 53 + shape.seed * 1.3) * shape.jitter * jitterMultiplier * 0.6

                        let x = centerX + shape.cx + jx
                        let y = centerY + shape.cy + jy

                        let alpha = shape.baseOpacity * fade * baseAlphaMultiplier

                        // Color selection
                        let color: Color
                        if isGodMode {
                            color = sin(shape.seed * 2.3 + t * 0.8) > 0.3 ? .red : Theme.orange
                        } else if isPlaying {
                            color = shape.seed.truncatingRemainder(dividingBy: 3) > 1 ? Color.white : Theme.orange
                        } else {
                            color = shape.seed.truncatingRemainder(dividingBy: 3) > 1 ? Color.white : Theme.ice
                        }

                        let shapePath = Self.buildPath(kind: shape.kind, size: shape.size, seed: shape.seed)

                        // Draw shape
                        var transform = CGAffineTransform.identity
                        transform = transform.translatedBy(x: x, y: y)
                        transform = transform.rotated(by: rot)
                        let transformed = shapePath.applying(transform)

                        context.stroke(
                            transformed,
                            with: .color(color.opacity(alpha)),
                            lineWidth: 1.2
                        )

                        // Mirror copy
                        if shape.mirror {
                            var mirrorTransform = CGAffineTransform.identity
                            mirrorTransform = mirrorTransform.translatedBy(x: 2 * centerX - x, y: y)
                            mirrorTransform = mirrorTransform.rotated(by: -rot)
                            let mirrored = shapePath.applying(mirrorTransform)
                            context.stroke(
                                mirrored,
                                with: .color(color.opacity(alpha * 0.6)),
                                lineWidth: 1.0
                            )
                        }
                    }

                    // --- Underline ---
                    let ulY = centerY + 58
                    let ulW: Double = 160
                    let ulX = centerX - ulW / 2
                    let ulAlpha = 0.3 + 0.2 * sin(t * 0.8)
                    let ulColor = isGodMode ? Theme.orange : (isPlaying ? Theme.orange : Theme.ice)
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
                .onChange(of: t) { _, newT in
                    // Respawn expired shapes and adjust pool size
                    shapes = shapes.filter { newT - $0.birthTime < $0.lifespan }
                    while shapes.count < shapeCount {
                        shapes.append(Self.spawnShape(at: newT))
                    }
                }
            }
            .allowsHitTesting(false)
            .onAppear {
                let now = Date.timeIntervalSinceReferenceDate
                shapes = (0..<shapeCount).map { _ in Self.spawnShape(at: now) }
            }

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

            // Master volume ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 4)
                    .frame(width: 64, height: 64)
                Circle()
                    .trim(from: 0, to: CGFloat(masterVolume))
                    .stroke(Theme.orange.opacity(0.7), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(masterVolume * 100))")
                    .font(.system(size: 16, design: .monospaced).bold())
                    .foregroundColor(Color.white.opacity(0.5))
            }
            .padding(.top, 6)

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
                    Text("beat \(transport.currentBeat)")
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

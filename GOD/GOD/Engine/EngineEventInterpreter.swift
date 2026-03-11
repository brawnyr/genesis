import Foundation

class EngineEventInterpreter: ObservableObject {
    @Published var lines: [TerminalLine] = []
    @Published var padIntensities: [Float] = Array(repeating: 0, count: 8)

    private let maxLines = 30

    // Previous state for diffing
    private var prevMuted: [Bool] = Array(repeating: false, count: 8)
    private var prevVolumes: [Float] = Array(repeating: 1.0, count: 8)
    private var prevPans: [Float] = Array(repeating: 0.5, count: 8)
    private var prevHP: [Float] = Array(repeating: 20.0, count: 8)
    private var prevLP: [Float] = Array(repeating: 20000.0, count: 8)
    private var prevPlaying: Bool = false
    private var prevCaptureState: String = "idle"
    private var loopHitCounts: [Int] = Array(repeating: 0, count: 8)
    private var loopHitVelocities: [[Int]] = Array(repeating: [], count: 8)

    // Decay constants
    private static let shortDecay: Float = 0.92
    private static let sustainDecay: Float = 0.98

    // Track which pads have active voices (set by engine)
    var activePadVoices: Set<Int> = []

    func appendLine(_ text: String) {
        let line = TerminalLine(text: text, isHighlight: false)
        lines.append(line)
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
    }

    func processHits(_ hits: [(padIndex: Int, position: Int, velocity: Int)],
                     padBank: PadBank, loopDurationMs: Double) {
        // Must reassign array (not mutate elements) to trigger @Published
        var intensities = padIntensities
        for hit in hits {
            let pad = padBank.pads[hit.padIndex]
            let name = pad.sample?.name ?? pad.name
            let durationMs = pad.sample?.durationMs ?? 0

            // Update visual intensity
            let velNorm = Float(hit.velocity) / 127.0
            intensities[hit.padIndex] = min(1.0, velNorm)

            // Track for loop summary
            loopHitCounts[hit.padIndex] += 1
            loopHitVelocities[hit.padIndex].append(hit.velocity)

            // Format hit event line
            let dur = Self.formatDuration(durationMs)
            let velDesc = hit.velocity > 90 ? " — hard hit" : ""
            appendLine("\(name.lowercased()) \(dur) — vel \(hit.velocity)\(velDesc)")
        }
        padIntensities = intensities
    }

    func processStateDiff(layers: [Layer], transport: Transport, capture: GodCapture,
                          padBank: PadBank, masterVolume: Float) {
        // Transport state changes
        if transport.isPlaying && !prevPlaying {
            let loopSec = Double(transport.loopLengthFrames) / Transport.sampleRate
            appendLine("▶ loop start — \(transport.barCount) bars @ \(transport.bpm)bpm (\(String(format: "%.1f", loopSec))s)")
        } else if !transport.isPlaying && prevPlaying {
            appendLine("■ stopped")
        }
        prevPlaying = transport.isPlaying

        // Mute changes
        for i in 0..<8 {
            if layers[i].isMuted != prevMuted[i] {
                let name = padBank.pads[i].sample?.name ?? padBank.pads[i].name
                if layers[i].isMuted {
                    appendLine("pad \(i + 1) \(name.lowercased()) muted ○")
                    var intensities = padIntensities
                    intensities[i] = 0
                    padIntensities = intensities
                } else {
                    appendLine("pad \(i + 1) \(name.lowercased()) unmuted ●")
                }
                prevMuted[i] = layers[i].isMuted
            }
        }

        // CC changes — only emit when value actually changes
        for i in 0..<8 {
            if abs(layers[i].volume - prevVolumes[i]) > 0.01 {
                appendLine("pad \(i + 1) vol → \(Int(layers[i].volume * 100))%")
                prevVolumes[i] = layers[i].volume
            }
            if abs(layers[i].pan - prevPans[i]) > 0.01 {
                appendLine("pad \(i + 1) pan → \(Self.formatPan(layers[i].pan))")
                prevPans[i] = layers[i].pan
            }
            if abs(layers[i].hpCutoff - prevHP[i]) > 1 {
                appendLine("pad \(i + 1) HP → \(Self.formatFrequency(layers[i].hpCutoff))")
                prevHP[i] = layers[i].hpCutoff
            }
            if abs(layers[i].lpCutoff - prevLP[i]) > 1 {
                appendLine("pad \(i + 1) LP → \(Self.formatFrequency(layers[i].lpCutoff))")
                prevLP[i] = layers[i].lpCutoff
            }
        }

        // Capture state
        let captureStr: String
        switch capture.state {
        case .idle: captureStr = "idle"
        case .armed: captureStr = "armed"
        case .recording: captureStr = "recording"
        }
        if captureStr != prevCaptureState {
            switch capture.state {
            case .armed: appendLine("capture armed — next loop boundary")
            case .recording: appendLine("capture recording ◉")
            case .idle:
                if prevCaptureState == "recording" {
                    appendLine("capture saved")
                }
            }
            prevCaptureState = captureStr
        }
    }

    func onLoopBoundary(layers: [Layer], padBank: PadBank, loopDurationMs: Double) {
        appendLine("loop boundary — wrap")

        // Emit layer summaries for pads with hits
        for i in 0..<8 where loopHitCounts[i] > 0 {
            let name = padBank.pads[i].sample?.name ?? padBank.pads[i].name
            let count = loopHitCounts[i]
            let vels = loopHitVelocities[i]
            let velMin = vels.min() ?? 0
            let velMax = vels.max() ?? 0
            let spread = velMax - velMin
            let spreadDesc = spread < 20 ? "tight" : "varying"
            let sampleMs = padBank.pads[i].sample?.durationMs ?? 0

            if sampleMs > loopDurationMs {
                let dur = Self.formatDuration(sampleMs)
                let others = (0..<8).filter { $0 != i && loopHitCounts[$0] > 0 }
                    .map { padBank.pads[$0].sample?.name.lowercased() ?? padBank.pads[$0].name.lowercased() }
                let onTop = others.isEmpty ? "" : " on top of \(others.joined(separator: ", "))"
                appendLine("\(name.lowercased()) loop int \(dur)\(onTop) (\(count) hits, \(spreadDesc) vel)")
            } else {
                appendLine("\(name.lowercased()) (\(count) hits, \(spreadDesc) vel \(velMin)-\(velMax))")
            }
        }

        // Reset loop counters
        loopHitCounts = Array(repeating: 0, count: 8)
        loopHitVelocities = Array(repeating: [], count: 8)
    }

    func tickVisuals() {
        // Must reassign array (not mutate elements) to trigger @Published
        var updated = padIntensities
        for i in 0..<8 {
            if activePadVoices.contains(i) {
                updated[i] = max(updated[i] * Self.sustainDecay, 0.3)
            } else if updated[i] > 0.01 {
                updated[i] *= Self.shortDecay
            } else {
                updated[i] = 0
            }
        }
        padIntensities = updated
    }

    // MARK: - Formatting helpers

    static func formatFrequency(_ hz: Float) -> String {
        if hz >= 1000 {
            return String(format: "%.1fkHz", hz / 1000.0)
        }
        return "\(Int(hz))Hz"
    }

    static func formatPan(_ pan: Float) -> String {
        if abs(pan - 0.5) < 0.01 { return "C" }
        if pan < 0.5 {
            let pct = Int(((0.5 - pan) * 100).rounded())
            return "L\(pct)"
        }
        let pct = Int(((pan - 0.5) * 100).rounded())
        return "R\(pct)"
    }

    static func formatDuration(_ ms: Double) -> String {
        let sec = ms / 1000.0
        if sec < 1.0 {
            let formatted = String(format: "%.2f", sec)
            let trimmed = formatted.hasPrefix("0") ? String(formatted.dropFirst()) : formatted
            if trimmed.hasSuffix("0") && !trimmed.hasSuffix(".0") {
                return String(trimmed.dropLast()) + "s"
            }
            return trimmed + "s"
        }
        return String(format: "%.1f", sec) + "s"
    }
}

import Foundation

enum LineKind {
    case system    // startup, init
    case transport // play, pause, stop, loop wrap
    case hit       // pad hits, velocity
    case state     // mute, unmute, volume, pan, CC
    case capture   // armed, recording, saved
    case browse    // sample browser events
    case oracle    // AI session observer
}

struct TerminalLine: Identifiable {
    private static var nextID: Int = 0
    let id: Int = {
        let val = nextID
        nextID += 1
        return val
    }()
    let text: String
    let kind: LineKind
    let isHighlight: Bool
    var padIndex: Int? = nil     // for hit lines — colors by pad
    let timestamp: Date = Date()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var timeString: String {
        Self.timeFormatter.string(from: timestamp)
    }
}

class EngineEventInterpreter: ObservableObject {
    @Published var lines: [TerminalLine] = []
    @Published var padIntensities: [Float] = Array(repeating: 0, count: PadBank.padCount)

    var oracle: SessionOracle?
    private let maxLines = 30

    // Previous state for diffing
    private struct PrevPadState {
        var muted: Bool = false
        var volume: Float = 0.25
        var pan: Float = 0.5
        var hp: Float = Layer.hpBypassFrequency
        var lp: Float = Layer.lpBypassFrequency
        var swing: Float = 0.5
    }
    private var prevPads: [PrevPadState] = Array(repeating: PrevPadState(), count: PadBank.padCount)
    private var prevPlaying: Bool = false
    private var prevCaptureState: String = "idle"
    private var loopHitCounts: [Int] = Array(repeating: 0, count: PadBank.padCount)
    private var loopHitVelocities: [[Int]] = Array(repeating: [], count: PadBank.padCount)

    // Decay constants
    private static let shortDecay: Float = 0.92
    private static let sustainDecay: Float = 0.98
    private static let sustainMinIntensity: Float = 0.3
    private static let intensityCutoff: Float = 0.01

    // Track which pads have active voices (set by engine)
    var activePadVoices: Set<Int> = []

    func appendLine(_ text: String, kind: LineKind = .system, padIndex: Int? = nil) {
        let line = TerminalLine(text: text, kind: kind, isHighlight: false, padIndex: padIndex)
        lines.append(line)
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
    }

    func processHits(_ hits: [(padIndex: Int, position: Int, velocity: Int)],
                     padBank: PadBank, loopDurationMs: Double,
                     loopLengthFrames: Int = 0, barCount: Int = 4) {
        var intensities = padIntensities
        for hit in hits {
            let name = PadBank.spliceFolderNames[hit.padIndex].uppercased()

            let velNorm = Float(hit.velocity) / 127.0
            intensities[hit.padIndex] = min(1.0, velNorm)

            loopHitCounts[hit.padIndex] += 1
            loopHitVelocities[hit.padIndex].append(hit.velocity)

            let beatStr = Self.formatBeatPosition(
                framePosition: hit.position,
                loopLengthFrames: loopLengthFrames,
                barCount: barCount
            )
            appendLine("\(name)  \(beatStr)", kind: .hit, padIndex: hit.padIndex)
        }
        padIntensities = intensities
    }

    static func formatBeatPosition(framePosition: Int, loopLengthFrames: Int, barCount: Int) -> String {
        guard loopLengthFrames > 0 else { return "1.1" }
        let totalBeats = barCount * Transport.beatsPerBar
        let totalSubdivisions = totalBeats * 4
        let subdivIndex = Int(Double(framePosition) / Double(loopLengthFrames) * Double(totalSubdivisions))
        let beat = subdivIndex / 4 + 1
        let subdivision = subdivIndex % 4 + 1
        return "\(beat).\(subdivision)"
    }

    func processStateDiff(layers: [Layer], transport: Transport, capture: GenesisCapture,
                          padBank: PadBank, masterVolume: Float) {
        if transport.isPlaying && !prevPlaying {
            let loopSec = Double(transport.loopLengthFrames) / Transport.sampleRate
            appendLine("▶ loop start — \(transport.barCount) bars @ \(transport.bpm)bpm (\(String(format: "%.1f", loopSec))s)", kind: .transport)
        } else if !transport.isPlaying && prevPlaying {
            appendLine("■ stopped", kind: .transport)
        }
        prevPlaying = transport.isPlaying

        for i in 0..<PadBank.padCount {
            if layers[i].isMuted != prevPads[i].muted {
                if layers[i].isMuted {
                    var intensities = padIntensities
                    intensities[i] = 0
                    padIntensities = intensities
                }
                prevPads[i].muted = layers[i].isMuted
            }
        }

        // CC changes from MIDI knobs — log every distinct change
        for i in 0..<PadBank.padCount {
            if abs(layers[i].volume - prevPads[i].volume) > 0.005 {
                let volDb = formatDb(linearToDb(layers[i].volume))
                appendLine("pad \(i + 1) vol → \(Int(layers[i].volume * 100))% (\(volDb))", kind: .state)
                prevPads[i].volume = layers[i].volume
            }
            if layers[i].pan != prevPads[i].pan {
                appendLine("pad \(i + 1) pan → \(Self.formatPan(layers[i].pan))", kind: .state)
                prevPads[i].pan = layers[i].pan
            }
            if layers[i].hpCutoff != prevPads[i].hp {
                appendLine("pad \(i + 1) HP → \(Self.formatFrequency(layers[i].hpCutoff))", kind: .state)
                prevPads[i].hp = layers[i].hpCutoff
            }
            if layers[i].lpCutoff != prevPads[i].lp {
                appendLine("pad \(i + 1) LP → \(Self.formatFrequency(layers[i].lpCutoff))", kind: .state)
                prevPads[i].lp = layers[i].lpCutoff
            }
            if layers[i].swing != prevPads[i].swing {
                let pct = Int((layers[i].swing - 0.5) / 0.25 * 100)
                appendLine("pad \(i + 1) swing → \(pct)%", kind: .state)
                prevPads[i].swing = layers[i].swing
            }
        }

        // Looper state from audio thread
        let captureStr: String
        switch capture.state {
        case .off: captureStr = "off"
        case .on: captureStr = "on"
        }
        if captureStr != prevCaptureState {
            switch capture.state {
            case .on: appendLine("looper on ◉", kind: .capture)
            case .off:
                if prevCaptureState == "on" {
                    appendLine("looper off — capture saved", kind: .capture)
                }
            }
            prevCaptureState = captureStr
        }
    }

    private var loopCount: Int = 0

    func onLoopBoundary(layers: [Layer], padBank: PadBank, loopDurationMs: Double, transport: Transport? = nil) {
        if let transport {
            oracle?.onLoopBoundary(layers: layers, padBank: padBank, transport: transport)
        }
        loopCount += 1
        appendLine("▶ loop \(loopCount) — wrap", kind: .transport)

        for i in 0..<PadBank.padCount where loopHitCounts[i] > 0 {
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
                let others = (0..<PadBank.padCount).filter { $0 != i && loopHitCounts[$0] > 0 }
                    .map { padBank.pads[$0].sample?.name.lowercased() ?? padBank.pads[$0].name.lowercased() }
                let onTop = others.isEmpty ? "" : " on top of \(others.joined(separator: ", "))"
                appendLine("\(name.lowercased()) loop int \(dur)\(onTop) (\(count) hits, \(spreadDesc) vel)", kind: .hit)
            } else {
                appendLine("\(name.lowercased()) (\(count) hits, \(spreadDesc) vel \(velMin)-\(velMax))", kind: .hit)
            }
        }

        loopHitCounts = Array(repeating: 0, count: PadBank.padCount)
        loopHitVelocities = Array(repeating: [], count: PadBank.padCount)
    }

    func tickVisuals() {
        var updated = padIntensities
        for i in 0..<PadBank.padCount {
            if activePadVoices.contains(i) {
                updated[i] = max(updated[i] * Self.sustainDecay, Self.sustainMinIntensity)
            } else if updated[i] > Self.intensityCutoff {
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

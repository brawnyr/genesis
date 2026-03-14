import Foundation

struct Hit {
    let position: Int  // frame offset in loop
    let velocity: Int  // 0-127
}

struct Layer {
    static let hpBypassFrequency: Float = 20.0
    static let lpBypassFrequency: Float = 20000.0

    let index: Int
    var name: String
    var hits: [Hit] = []
    var isMuted: Bool = false
    var isRecording: Bool = false
    var hasNewHits: Bool = false
    var volume: Float = 0.25  // -12 dB default
    var pan: Float = 0.5            // 0.0 = left, 0.5 = center, 1.0 = right
    var hpCutoff: Float = Layer.hpBypassFrequency      // Hz — 20 = no effect
    var lpCutoff: Float = Layer.lpBypassFrequency   // Hz — 20000 = no effect
    var choke: Bool = true
    var looper: Bool = false
    var swing: Float = 0.5 {
        didSet { swing = max(0.5, min(0.75, swing)) }
    }
    private var previousHits: [Hit]?

    init(index: Int, name: String) {
        self.index = index
        self.name = name
    }

    mutating func addHit(at position: Int, velocity: Int) {
        let hit = Hit(position: position, velocity: velocity)
        // Binary search insertion — O(log n) vs O(n log n) full sort
        var lo = 0, hi = hits.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if hits[mid].position < position { lo = mid + 1 } else { hi = mid }
        }
        hits.insert(hit, at: lo)
    }

    func hits(inRange range: Range<Int>) -> [Hit] {
        guard !hits.isEmpty else { return [] }
        // Binary search for start of range
        var lo = 0, hi = hits.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if hits[mid].position < range.lowerBound { lo = mid + 1 } else { hi = mid }
        }
        let start = lo
        // Linear scan from start (most ranges are short relative to total hits)
        var result: [Hit] = []
        for i in start..<hits.count {
            if hits[i].position >= range.upperBound { break }
            result.append(hits[i])
        }
        return result
    }

    mutating func clear() {
        previousHits = hits
        hits.removeAll()
        isRecording = false
        hasNewHits = false
    }

    mutating func undo() {
        guard let prev = previousHits else { return }
        hits = prev
        previousHits = nil
    }

    var canUndo: Bool { previousHits != nil }

    var statusLine: String {
        var parts: [String] = []
        if isMuted { parts.append("MUTE") }
        if looper { parts.append("loop:ON") }
        let swingPct = Int((swing - 0.5) / 0.25 * 100)
        if swingPct != 0 { parts.append("sw:\(swingPct)%") }
        let pan = EngineEventInterpreter.formatPan(pan)
        if pan != "C" { parts.append("pan:\(pan)") }
        if hpCutoff > 21 { parts.append("hp:\(EngineEventInterpreter.formatFrequency(hpCutoff))") }
        if lpCutoff < 19999 { parts.append("lp:\(EngineEventInterpreter.formatFrequency(lpCutoff))") }
        return parts.isEmpty ? "" : parts.joined(separator: " ")
    }
}

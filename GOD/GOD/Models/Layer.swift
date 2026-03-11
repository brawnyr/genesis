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
    var volume: Float = 1.0
    var pan: Float = 0.5            // 0.0 = left, 0.5 = center, 1.0 = right
    var hpCutoff: Float = Layer.hpBypassFrequency      // Hz — 20 = no effect
    var lpCutoff: Float = Layer.lpBypassFrequency   // Hz — 20000 = no effect
    var cut: Bool = false
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
        hits.filter { range.contains($0.position) }
    }

    mutating func clear() {
        previousHits = hits
        hits.removeAll()
    }

    mutating func undo() {
        guard let prev = previousHits else { return }
        hits = prev
        previousHits = nil
    }

    var canUndo: Bool { previousHits != nil }
}

import Foundation

struct Hit {
    let position: Int  // frame offset in loop
    let velocity: Int  // 0-127
}

struct Layer {
    let index: Int
    var name: String
    var hits: [Hit] = []
    var isMuted: Bool = false
    var volume: Float = 1.0
    var pan: Float = 0.5            // 0.0 = left, 0.5 = center, 1.0 = right
    var hpCutoff: Float = 20.0      // Hz — 20 = no effect
    var lpCutoff: Float = 20000.0   // Hz — 20000 = no effect
    private var previousHits: [Hit]?

    init(index: Int, name: String) {
        self.index = index
        self.name = name
    }

    mutating func addHit(at position: Int, velocity: Int) {
        hits.append(Hit(position: position, velocity: velocity))
        hits.sort { $0.position < $1.position }
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

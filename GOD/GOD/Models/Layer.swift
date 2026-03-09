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

    mutating func addHit(at position: Int, velocity: Int) {
        hits.append(Hit(position: position, velocity: velocity))
        hits.sort { $0.position < $1.position }
    }

    func hits(inRange range: Range<Int>) -> [Hit] {
        hits.filter { range.contains($0.position) }
    }

    mutating func clear() {
        hits.removeAll()
    }
}

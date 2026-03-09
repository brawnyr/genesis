import Foundation

struct Voice {
    let sample: Sample
    let velocity: Float
    var position: Int = 0

    mutating func fill(into buffer: inout [Float], count: Int) -> Bool {
        let remaining = sample.data.count - position
        let toWrite = min(count, remaining)

        for i in 0..<toWrite {
            buffer[i] += sample.data[position + i] * velocity
        }

        position += toWrite
        return position >= sample.data.count
    }
}

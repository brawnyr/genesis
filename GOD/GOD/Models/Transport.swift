import Foundation

struct Transport {
    static let sampleRate: Double = 44100.0
    private static let validBarCounts: Set<Int> = [1, 2, 4]

    var bpm: Int = 120 {
        didSet { bpm = max(1, min(999, bpm)) }
    }

    var barCount: Int = 4 {
        didSet {
            if !Self.validBarCounts.contains(barCount) {
                barCount = oldValue
            }
        }
    }

    var position: Int = 0
    var isPlaying: Bool = false

    var loopLengthFrames: Int {
        let beatsPerLoop = Double(barCount * 4)
        let secondsPerBeat = 60.0 / Double(bpm)
        return Int(beatsPerLoop * secondsPerBeat * Self.sampleRate)
    }

    mutating func advance(frames: Int) -> Bool {
        position += frames
        if position >= loopLengthFrames {
            position -= loopLengthFrames
            return true
        }
        return false
    }

    mutating func reset() {
        position = 0
        isPlaying = false
    }
}

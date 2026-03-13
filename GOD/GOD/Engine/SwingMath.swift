import Foundation

enum SwingMath {
    static func swungPosition(hitFrame: Int, swing: Float, sixteenthLength: Int, loopLength: Int) -> Int {
        guard swing > 0.5, sixteenthLength > 0, loopLength > 0 else { return hitFrame }
        let slotIndex = Int((Float(hitFrame) / Float(sixteenthLength)).rounded())
        guard slotIndex % 2 == 1 else { return hitFrame }
        let offset = Int((swing - 0.5) * Float(sixteenthLength))
        let swung = hitFrame + offset
        return swung % loopLength
    }

    static func maxSwingOffset(sixteenthLength: Int) -> Int {
        return Int(0.25 * Float(sixteenthLength))
    }

    static func sixteenthLength(loopLengthFrames: Int, beatsPerLoop: Int) -> Int {
        guard beatsPerLoop > 0 else { return 0 }
        return loopLengthFrames / (beatsPerLoop * 4)
    }
}

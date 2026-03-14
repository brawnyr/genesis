import Foundation

enum SwingMath {
    static func swungPosition(hitFrame: Int, swing: Float, sixteenthLength: Int, loopLength: Int) -> Int {
        guard swing > 0.5, sixteenthLength > 0, loopLength > 0 else { return hitFrame }

        // Find which sixteenth slot this hit is nearest to
        let exactSlot = Float(hitFrame) / Float(sixteenthLength)
        let nearestSlot = Int(exactSlot.rounded())

        // Only swing if the hit is actually close to a slot (within 40% of a sixteenth)
        let distanceFromSlot = abs(exactSlot - Float(nearestSlot))
        guard distanceFromSlot < 0.4 else { return hitFrame }

        // Only push odd slots (offbeats: the "and"s)
        guard nearestSlot % 2 == 1 else { return hitFrame }

        // Push the offbeat forward — full range: 0% to 100% of a sixteenth
        // swing 0.5 = straight, swing 0.75 = triplet feel (2:1), swing 1.0 = max push
        let offset = Int(roundf((swing - 0.5) * 2.0 * Float(sixteenthLength)))
        let swung = hitFrame + offset
        return ((swung % loopLength) + loopLength) % loopLength
    }

    static func maxSwingOffset(sixteenthLength: Int) -> Int {
        // Full sixteenth push at max swing
        return sixteenthLength
    }

    static func sixteenthLength(loopLengthFrames: Int, beatsPerLoop: Int) -> Int {
        guard beatsPerLoop > 0 else { return 0 }
        return loopLengthFrames / (beatsPerLoop * 4)
    }
}

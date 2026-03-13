import Testing
@testable import Genesis

@Test func swungPositionNoSwing() {
    let result = SwingMath.swungPosition(hitFrame: 1000, swing: 0.5, sixteenthLength: 5513, loopLength: 88200)
    #expect(result == 1000)
}

@Test func swungPositionEvenSlotUnchanged() {
    let sixteenth = 5513
    let result = SwingMath.swungPosition(hitFrame: 0, swing: 0.66, sixteenthLength: sixteenth, loopLength: 88200)
    #expect(result == 0)
}

@Test func swungPositionOddSlotShifted() {
    let sixteenth = 5512
    let hitFrame = sixteenth
    let result = SwingMath.swungPosition(hitFrame: hitFrame, swing: 0.66, sixteenthLength: sixteenth, loopLength: 88200)
    let expectedOffset = Int(Float(0.66 - 0.5) * Float(sixteenth))
    #expect(result == hitFrame + expectedOffset)
}

@Test func swungPositionWrapsAtLoopEnd() {
    let loopLen = 88200
    let sixteenth = loopLen / 16
    let hitFrame = loopLen - 100
    let result = SwingMath.swungPosition(hitFrame: hitFrame, swing: 0.75, sixteenthLength: sixteenth, loopLength: loopLen)
    #expect(result >= 0)
    #expect(result < loopLen)
}

@Test func maxSwingOffsetCalculation() {
    let sixteenth = 5512
    let maxOffset = SwingMath.maxSwingOffset(sixteenthLength: sixteenth)
    #expect(maxOffset == Int(0.25 * Float(sixteenth)))
}

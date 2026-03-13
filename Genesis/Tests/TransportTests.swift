import Testing
@testable import Genesis

@Test func transportAdvanceWraps() {
    var transport = Transport()
    let nearEnd = transport.loopLengthFrames - 10
    transport.position = nearEnd
    let wrapped = transport.advance(frames: 20)
    #expect(wrapped == true)
    #expect(transport.position == 10)
}

@Test func transportAdvanceExactBoundary() {
    var transport = Transport()
    let exactEnd = transport.loopLengthFrames - 512
    transport.position = exactEnd
    let wrapped = transport.advance(frames: 512)
    #expect(wrapped == true)
    #expect(transport.position == 0)
}

@Test func transportBPMClamps() {
    var transport = Transport()
    transport.bpm = 0
    #expect(transport.bpm == 1)
    transport.bpm = 1000
    #expect(transport.bpm == 999)
}

@Test func transportBarCountValidation() {
    var transport = Transport()
    transport.barCount = 2
    #expect(transport.barCount == 2)
    transport.barCount = 3
    #expect(transport.barCount == 2) // unchanged, 3 is invalid
}

@Test func transportCurrentBeat() {
    var t = Transport()
    t.bpm = 120
    t.barCount = 4
    t.isPlaying = true
    t.position = 0
    #expect(t.currentBeat == 1)

    // At exactly 1 beat in (0.5s at 120bpm = 22050 frames)
    t.position = 22050
    #expect(t.currentBeat == 2)

    // At 4 beats in
    t.position = 88200
    #expect(t.currentBeat == 5)
}

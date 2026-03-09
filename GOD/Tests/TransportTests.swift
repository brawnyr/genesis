import Testing
@testable import GOD

@Test func transportDefaults() {
    let transport = Transport()
    #expect(transport.bpm == 120)
    #expect(transport.barCount == 4)
    #expect(transport.position == 0)
    #expect(transport.isPlaying == false)
}

@Test func transportLoopLength() {
    let transport = Transport()
    // 4 bars × 4 beats × (60/120) × 44100 = 352800
    #expect(transport.loopLengthFrames == 352800)
}

@Test func transportAdvanceWraps() {
    var transport = Transport()
    transport.position = 352790
    let wrapped = transport.advance(frames: 20)
    #expect(wrapped == true)
    #expect(transport.position == 10)
}

@Test func transportAdvanceNoWrap() {
    var transport = Transport()
    transport.position = 100
    let wrapped = transport.advance(frames: 50)
    #expect(wrapped == false)
    #expect(transport.position == 150)
}

@Test func transportBPMClamps() {
    var transport = Transport()
    transport.bpm = 300
    #expect(transport.bpm == 300)
    transport.bpm = 0
    #expect(transport.bpm == 1)
}

@Test func transportBarCountValidation() {
    var transport = Transport()
    transport.barCount = 2
    #expect(transport.barCount == 2)
    transport.barCount = 3
    #expect(transport.barCount == 2) // unchanged, 3 is invalid
}

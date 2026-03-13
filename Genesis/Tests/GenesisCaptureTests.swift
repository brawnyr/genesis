import Testing
@testable import Genesis

@Test func captureStateTransitions() {
    var capture = GenesisCapture()
    #expect(capture.state == .off)

    capture.toggle()
    #expect(capture.state == .on)

    capture.toggle()
    #expect(capture.state == .off)
}

@Test func captureAppendWhenOffIsNoop() {
    var capture = GenesisCapture()
    let buffer: [Float] = [0.1, 0.2, 0.3]

    // Off — append should be ignored
    capture.append(left: buffer, right: buffer)
    #expect(capture.accumulatedFrames == 0)
}

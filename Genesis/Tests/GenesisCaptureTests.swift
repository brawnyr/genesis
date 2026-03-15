import Testing
@testable import Genesis

@Test func captureStateTransitions() {
    var capture = GenesisCapture()
    #expect(capture.state == .off)

    capture.startCapture()
    #expect(capture.state == .on)

    let chunks = capture.stopCapture()
    #expect(capture.state == .off)
    #expect(chunks.isEmpty)
}

@Test func captureAppendWhenOffIsNoop() {
    var capture = GenesisCapture()
    let buffer: [Float] = [0.1, 0.2, 0.3]

    // Off — append should be ignored
    buffer.withUnsafeBufferPointer { left in
        buffer.withUnsafeBufferPointer { right in
            capture.appendFromBuffers(left: left, right: right)
        }
    }
    #expect(capture.accumulatedFrames == 0)
}

@Test func captureAccumulatesFrames() {
    var capture = GenesisCapture()
    capture.startCapture()

    let buffer: [Float] = [0.1, 0.2, 0.3, 0.4]
    buffer.withUnsafeBufferPointer { left in
        buffer.withUnsafeBufferPointer { right in
            capture.appendFromBuffers(left: left, right: right)
        }
    }
    #expect(capture.accumulatedFrames == 4)

    let chunks = capture.stopCapture()
    #expect(chunks.count == 1)
    #expect(chunks[0].0.count == 4)
    #expect(chunks[0].1.count == 4)
}

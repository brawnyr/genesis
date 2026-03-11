import Testing
@testable import GOD

@Test func captureStateTransitions() {
    var capture = GodCapture()
    #expect(capture.state == .idle)

    capture.toggle()
    #expect(capture.state == .armed)

    capture.onLoopBoundary()
    #expect(capture.state == .recording)

    capture.toggle()
    #expect(capture.state == .idle)
}

@Test func captureAccumulatesBuffers() {
    var capture = GodCapture()
    capture.toggle() // armed
    capture.onLoopBoundary() // recording

    let buffer: [Float] = [0.1, 0.2, 0.3]
    capture.append(left: buffer, right: buffer)
    capture.append(left: buffer, right: buffer)
    #expect(capture.accumulatedFrames == 6)
}

import Testing
@testable import GOD

@Test func sampleDurationMs() {
    // 44100 frames at 44100Hz = 1000ms
    let sample = Sample(name: "test", left: [Float](repeating: 0, count: 44100),
                        right: [Float](repeating: 0, count: 44100), sampleRate: 44100)
    #expect(sample.durationMs == 1000.0)
}

@Test func sampleDurationMsShort() {
    // 22050 frames at 44100Hz = 500ms
    let sample = Sample(name: "short", left: [Float](repeating: 0, count: 22050),
                        right: [Float](repeating: 0, count: 22050), sampleRate: 44100)
    #expect(sample.durationMs == 500.0)
}

import Testing
@testable import Genesis

@Test func metronomeDownbeatLouder() {
    let normal = Metronome.click(beatIndex: 1)
    let downbeat = Metronome.click(beatIndex: 0)
    let normalPeak = normal.left.map { abs($0) }.max()!
    let downbeatPeak = downbeat.left.map { abs($0) }.max()!
    #expect(downbeatPeak > normalPeak)
}

@Test func metronomeBeatLengthEdgeBPM() {
    // BPM 1 = 60 seconds per beat = 2,646,000 frames
    #expect(Metronome.beatLengthFramesStatic(bpm: 1, sampleRate: 44100) == 2_646_000)
    // BPM 999 = ~0.06s per beat
    let fast = Metronome.beatLengthFramesStatic(bpm: 999, sampleRate: 44100)
    #expect(fast > 0)
    #expect(fast < 3000)
}

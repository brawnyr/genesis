import Testing
@testable import GOD

@Test func metronomeClickGeneration() {
    let click = Metronome.click(isDownbeat: false)
    #expect(click.frameCount > 0)
    #expect(click.frameCount <= 4410) // max ~100ms
}

@Test func metronomeDownbeatLouder() {
    let normal = Metronome.click(isDownbeat: false)
    let downbeat = Metronome.click(isDownbeat: true)
    let normalPeak = normal.left.map { abs($0) }.max()!
    let downbeatPeak = downbeat.left.map { abs($0) }.max()!
    #expect(downbeatPeak > normalPeak)
}

@Test func metronomeBeatPosition() {
    let met = Metronome()
    #expect(met.beatLengthFrames(bpm: 120, sampleRate: 44100) == 22050)
}

@Test func metronomeClickIsStereo() {
    let click = Metronome.click(isDownbeat: true)
    #expect(click.left.count == click.right.count)
    // Metronome clicks are centered — identical L/R
    #expect(click.left == click.right)
}

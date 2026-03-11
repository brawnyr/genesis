import Testing
@testable import GOD

@Test func metronomeClickGeneration() {
    let click = Metronome.generateClick(isDownbeat: false, sampleRate: 44100)
    #expect(click.frameCount > 0)
    #expect(click.frameCount <= 4410) // max ~100ms
}

@Test func metronomeDownbeatLouder() {
    let normal = Metronome.generateClick(isDownbeat: false, sampleRate: 44100)
    let downbeat = Metronome.generateClick(isDownbeat: true, sampleRate: 44100)
    let normalPeak = normal.left.map { abs($0) }.max()!
    let downbeatPeak = downbeat.left.map { abs($0) }.max()!
    #expect(downbeatPeak > normalPeak)
}

@Test func metronomeBeatPosition() {
    let met = Metronome()
    #expect(met.beatLengthFrames(bpm: 120, sampleRate: 44100) == 22050)
}

@Test func metronomeClickIsStereo() {
    let click = Metronome.generateClick(isDownbeat: true, sampleRate: 44100)
    #expect(click.left.count == click.right.count)
    // Metronome clicks are centered — identical L/R
    #expect(click.left == click.right)
}

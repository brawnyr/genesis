import Testing
@testable import GOD

@Test func metronomeClickGeneration() {
    let click = Metronome.generateClick(isDownbeat: false, sampleRate: 44100)
    #expect(click.count > 0)
    #expect(click.count <= 4410) // max ~100ms
}

@Test func metronomeDownbeatLouder() {
    let normal = Metronome.generateClick(isDownbeat: false, sampleRate: 44100)
    let downbeat = Metronome.generateClick(isDownbeat: true, sampleRate: 44100)
    let normalPeak = normal.map { abs($0) }.max()!
    let downbeatPeak = downbeat.map { abs($0) }.max()!
    #expect(downbeatPeak > normalPeak)
}

@Test func metronomeBeatPosition() {
    let met = Metronome()
    #expect(met.beatLengthFrames(bpm: 120, sampleRate: 44100) == 22050)
}

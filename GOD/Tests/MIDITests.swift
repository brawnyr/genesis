import Testing
@testable import GOD

@Test func layerHasVolume() {
    var layer = Layer(index: 0, name: "TEST")
    #expect(layer.volume == 1.0)
    layer.volume = 0.5
    #expect(layer.volume == 0.5)
}

@Test func voiceHasPadIndex() {
    let sample = Sample(name: "test", data: [0.1, 0.2], sampleRate: 44100)
    let voice = Voice(sample: sample, velocity: 1.0, padIndex: 3)
    #expect(voice.padIndex == 3)
}

@Test func padHasIsOneShot() {
    var pad = Pad(index: 0, midiNote: 36, name: "TEST")
    #expect(pad.isOneShot == true)
    pad.isOneShot = false
    #expect(pad.isOneShot == false)
}

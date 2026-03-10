import Testing
@testable import GOD

@Test func layerHasVolume() {
    var layer = Layer(index: 0, name: "TEST")
    #expect(layer.volume == 1.0)
    layer.volume = 0.5
    #expect(layer.volume == 0.5)
}

@Test func voiceHasPadIndex() {
    let sample = Sample(name: "test", left: [0.1, 0.2], right: [0.1, 0.2], sampleRate: 44100)
    let voice = Voice(sample: sample, velocity: 1.0, padIndex: 3)
    #expect(voice.padIndex == 3)
}

@Test func padHasIsOneShot() {
    var pad = Pad(index: 0, midiNote: 36, name: "TEST")
    #expect(pad.isOneShot == true)
    pad.isOneShot = false
    #expect(pad.isOneShot == false)
}

@Test @MainActor func noteOnTriggersPadHit() {
    let engine = GodEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "kick", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.togglePlay()

    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)

    let padVoices = engine.voices.filter { $0.padIndex == 0 }
    #expect(padVoices.count >= 1)
}

@Test @MainActor func noteOnOutOfRangeIgnored() {
    let engine = GodEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "kick", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.togglePlay()

    engine.midiRingBuffer.write(.noteOn(note: 99, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)

    let padVoices = engine.voices.filter { $0.padIndex >= 0 }
    #expect(padVoices.count == 0)
}

@Test @MainActor func noteOffIgnoredForOneShot() {
    let engine = GodEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "kick", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.togglePlay()

    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)
    let voicesBefore = engine.voices.filter { $0.padIndex == 0 }.count

    engine.midiRingBuffer.write(.noteOff(note: 36))
    let _ = engine.processBlock(frameCount: 512)

    let voicesAfter = engine.voices.filter { $0.padIndex == 0 }.count
    #expect(voicesAfter == voicesBefore)
}

@Test @MainActor func noteOffStopsHoldModeVoice() {
    let engine = GodEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "kick", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.padBank.pads[0].isOneShot = false
    engine.togglePlay()

    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)
    #expect(engine.voices.filter { $0.padIndex == 0 }.count >= 1)

    engine.midiRingBuffer.write(.noteOff(note: 36))
    let _ = engine.processBlock(frameCount: 512)

    #expect(engine.voices.filter { $0.padIndex == 0 }.count == 0)
}


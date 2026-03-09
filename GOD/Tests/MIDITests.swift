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

@Test @MainActor func noteOnTriggersPadHit() {
    let engine = GodEngine()
    let sample = Sample(name: "kick", data: [Float](repeating: 0.5, count: 44100), sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.togglePlay()

    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)

    let padVoices = engine.voices.filter { $0.padIndex == 0 }
    #expect(padVoices.count >= 1)
}

@Test @MainActor func noteOnOutOfRangeIgnored() {
    let engine = GodEngine()
    let sample = Sample(name: "kick", data: [Float](repeating: 0.5, count: 44100), sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.togglePlay()

    engine.midiRingBuffer.write(.noteOn(note: 99, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)

    let padVoices = engine.voices.filter { $0.padIndex >= 0 }
    #expect(padVoices.count == 0)
}

@Test @MainActor func noteOffIgnoredForOneShot() {
    let engine = GodEngine()
    let sample = Sample(name: "kick", data: [Float](repeating: 0.5, count: 44100), sampleRate: 44100)
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
    let sample = Sample(name: "kick", data: [Float](repeating: 0.5, count: 44100), sampleRate: 44100)
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

@Test @MainActor func ccSetsLayerVolume() {
    let engine = GodEngine()
    engine.togglePlay()

    // CC 14 = layer 0, value 64 ≈ 0.503
    engine.midiRingBuffer.write(.cc(number: 14, value: 64))
    let _ = engine.processBlock(frameCount: 512)

    // Now trigger a note — velocity should be scaled by layer volume
    let sample = Sample(name: "kick", data: [Float](repeating: 1.0, count: 44100), sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 127))
    let _ = engine.processBlock(frameCount: 512)

    if let voice = engine.voices.first(where: { $0.padIndex == 0 }) {
        #expect(voice.velocity < 0.6)
        #expect(voice.velocity > 0.4)
    } else {
        Issue.record("Expected voice for pad 0")
    }
}

@Test @MainActor func ccOutOfRangeIgnored() {
    let engine = GodEngine()
    engine.togglePlay()

    // CC 1 is not mapped to any layer
    engine.midiRingBuffer.write(.cc(number: 1, value: 127))
    let _ = engine.processBlock(frameCount: 512)

    // Trigger note — should be full volume (layer volume unchanged)
    let sample = Sample(name: "kick", data: [Float](repeating: 1.0, count: 44100), sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 127))
    let _ = engine.processBlock(frameCount: 512)

    if let voice = engine.voices.first(where: { $0.padIndex == 0 }) {
        #expect(voice.velocity > 0.99)
    } else {
        Issue.record("Expected voice for pad 0")
    }
}

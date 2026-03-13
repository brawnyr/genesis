import Testing
@testable import Genesis

@Test @MainActor func noteOnTriggersPadHit() {
    let engine = GenesisEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "kick", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.togglePlay()

    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)

    let padVoices = engine.voicePool.slots.filter { $0.active && $0.padIndex == 0 }
    #expect(padVoices.count >= 1)
}

@Test @MainActor func noteOffStopsHoldModeVoice() {
    let engine = GenesisEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "kick", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.padBank.pads[0].isOneShot = false
    engine.togglePlay()

    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)
    #expect(engine.voicePool.slots.filter { $0.active && $0.padIndex == 0 }.count >= 1)

    engine.midiRingBuffer.write(.noteOff(note: 36))
    let _ = engine.processBlock(frameCount: 512)

    #expect(engine.voicePool.slots.filter { $0.active && $0.padIndex == 0 }.count == 0)
}

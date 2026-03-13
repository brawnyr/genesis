import Testing
@testable import GOD

@Test @MainActor func engineActivePadTracking() {
    let engine = GodEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "kick", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.padBank.assign(sample: sample, toPad: 3)
    engine.togglePlay()

    // Hit pad 3 to make it active
    engine.midiRingBuffer.write(.noteOn(note: 39, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)

    // Active pad should now be 3 (set by audio thread)
    #expect(engine.audio.activePadIndex == 3)

    // CC 74 (volume knob) should target the active pad (3), not pad 0
    engine.midiRingBuffer.write(.cc(number: 74, value: 64))
    let _ = engine.processBlock(frameCount: 512)

    // Layer 3 volume should be ~0.5 (64/127), layer 0 should be unchanged at 1.0
    #expect(engine.audio.layers[3].volume < 0.6)
    #expect(engine.audio.layers[3].volume > 0.4)
    #expect(engine.audio.layers[0].volume == 1.0)
}

@Test @MainActor func engineTcpsChopsVoices() {
    let engine = GodEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "808", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.togglePlay()

    // First hit — should create 1 voice
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)
    #expect(engine.voices.filter { $0.padIndex == 0 }.count == 1)

    // Second hit — tcps should remove first, add new = still 1 voice
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)
    #expect(engine.voices.filter { $0.padIndex == 0 }.count == 1)
}

@Test @MainActor func engineNoTcpsStacksVoices() {
    let engine = GodEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "808", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.toggleTcps(pad: 0)  // turn OFF tcps so voices stack
    engine.togglePlay()

    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)

    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)

    #expect(engine.voices.filter { $0.padIndex == 0 }.count == 2)
}

@Test @MainActor func engineCCOutOfRangeIgnored() {
    let engine = GodEngine()
    engine.togglePlay()

    // CC 1 is not mapped
    engine.midiRingBuffer.write(.cc(number: 1, value: 127))
    let _ = engine.processBlock(frameCount: 512)

    let data = [Float](repeating: 1.0, count: 44100)
    let sample = Sample(name: "kick", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 127))
    let _ = engine.processBlock(frameCount: 512)

    if let voice = engine.voices.first(where: { $0.padIndex == 0 }) {
        #expect(voice.velocity > 0.99)
    } else {
        Issue.record("Expected voice for pad 0")
    }
}

@Test @MainActor func engineUndoLastClear() {
    let engine = GodEngine()
    engine.layers[0].addHit(at: 100, velocity: 100)
    engine.layers[0].addHit(at: 200, velocity: 80)
    engine.audio.layers[0].addHit(at: 100, velocity: 100)
    engine.audio.layers[0].addHit(at: 200, velocity: 80)
    engine.clearLayer(0)
    #expect(engine.layers[0].hits.count == 0)
    #expect(engine.audio.layers[0].hits.count == 0)

    engine.undoLastClear()
    #expect(engine.layers[0].hits.count == 2)
    #expect(engine.audio.layers[0].hits.count == 2)
}

@Test @MainActor func engineCycleBarCount() {
    let engine = GodEngine()
    // Default is 4, cycling backward should go to 2
    engine.cycleBarCount(forward: false)
    #expect(engine.transport.barCount == 2)
    engine.cycleBarCount(forward: false)
    #expect(engine.transport.barCount == 1)
    // Can't go below 1
    engine.cycleBarCount(forward: false)
    #expect(engine.transport.barCount == 1)
    // Forward back to 4
    engine.cycleBarCount(forward: true)
    engine.cycleBarCount(forward: true)
    #expect(engine.transport.barCount == 4)
}

@Test @MainActor func engineSetMasterVolumeClamped() {
    let engine = GodEngine()
    engine.setMasterVolume(0.5)
    #expect(engine.audio.masterVolume == 0.5)

    engine.setMasterVolume(-0.5)
    #expect(engine.audio.masterVolume == 0.0)

    engine.setMasterVolume(2.0)
    #expect(engine.audio.masterVolume == 1.0)
}

@Test @MainActor func engineCC18SetsSwing() {
    let engine = GodEngine()
    engine.togglePlay()

    // CC 18 value 0 → swing 0.5 (straight)
    engine.midiRingBuffer.write(.cc(number: 18, value: 0))
    let _ = engine.processBlock(frameCount: 512)
    #expect(engine.audio.layers[0].swing == 0.5)

    // CC 18 value 127 → swing 0.75 (max)
    engine.midiRingBuffer.write(.cc(number: 18, value: 127))
    let _ = engine.processBlock(frameCount: 512)
    #expect(abs(engine.audio.layers[0].swing - 0.75) < 0.01)

    // CC 18 value 64 → swing ~0.625
    engine.midiRingBuffer.write(.cc(number: 18, value: 64))
    let _ = engine.processBlock(frameCount: 512)
    #expect(engine.audio.layers[0].swing > 0.6)
    #expect(engine.audio.layers[0].swing < 0.65)
}

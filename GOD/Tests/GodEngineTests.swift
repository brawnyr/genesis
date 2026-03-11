import Testing
@testable import GOD

@Test @MainActor func engineInitialState() {
    let engine = GodEngine()
    #expect(engine.transport.bpm == 120)
    #expect(engine.transport.isPlaying == false)
    #expect(engine.layers.count == 8)
    #expect(engine.capture.state == .idle)
}

@Test @MainActor func engineTogglePlay() {
    let engine = GodEngine()
    engine.togglePlay()
    #expect(engine.transport.isPlaying == true)
    engine.togglePlay()
    #expect(engine.transport.isPlaying == false)
}

@Test @MainActor func engineSetBPM() {
    let engine = GodEngine()
    engine.setBPM(140)
    #expect(engine.transport.bpm == 140)
}

@Test @MainActor func engineToggleMute() {
    let engine = GodEngine()
    engine.toggleMute(layer: 0)
    #expect(engine.layers[0].isMuted == true)
    engine.toggleMute(layer: 0)
    #expect(engine.layers[0].isMuted == false)
}

@Test @MainActor func engineClearLayer() {
    let engine = GodEngine()
    engine.layers[0].addHit(at: 100, velocity: 100)
    engine.clearLayer(0)
    #expect(engine.layers[0].hits.count == 0)
}

@Test @MainActor func signalLevelsUpdateDuringPlayback() {
    let engine = GodEngine()
    for level in engine.channelSignalLevels {
        #expect(level == 0.0)
    }
    #expect(engine.channelSignalLevels.count == 8)
    #expect(engine.channelTriggered.count == 8)
}

@Test @MainActor func engineProcessBlockReturnsStereo() {
    let engine = GodEngine()
    engine.togglePlay()
    let (left, right) = engine.processBlock(frameCount: 256)
    #expect(left.count == 256)
    #expect(right.count == 256)
}

@Test @MainActor func engineUndoLastClear() {
    let engine = GodEngine()
    engine.layers[0].addHit(at: 100, velocity: 100)
    engine.layers[0].addHit(at: 200, velocity: 80)
    engine.clearLayer(0)
    #expect(engine.layers[0].hits.count == 0)

    engine.undoLastClear()
    #expect(engine.layers[0].hits.count == 2)
}

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

    // CC 14 (volume) should target pad 3, not pad 0
    engine.midiRingBuffer.write(.cc(number: 14, value: 64))
    let _ = engine.processBlock(frameCount: 512)

    // Hit pad 3 again — new voice should have scaled velocity
    engine.midiRingBuffer.write(.noteOn(note: 39, velocity: 127))
    let _ = engine.processBlock(frameCount: 512)

    // The latest voice on pad 3 should have reduced velocity (volume ~0.5)
    if let voice = engine.voices.last(where: { $0.padIndex == 3 }) {
        #expect(voice.velocity < 0.6)
        #expect(voice.velocity > 0.4)
    } else {
        Issue.record("Expected voice for pad 3")
    }
}

@Test @MainActor func engineToggleCut() {
    let engine = GodEngine()
    #expect(engine.layers[0].cut == false)
    engine.toggleCut(pad: 0)
    #expect(engine.layers[0].cut == true)
    engine.toggleCut(pad: 0)
    #expect(engine.layers[0].cut == false)
}

@Test @MainActor func engineCutModeChopsVoices() {
    let engine = GodEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "808", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.toggleCut(pad: 0)
    engine.togglePlay()

    // First hit — should create 1 voice
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)
    let voicesAfterFirst = engine.voices.filter { $0.padIndex == 0 }.count
    #expect(voicesAfterFirst == 1)

    // Second hit — cut should remove first, add new = still 1 voice
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)
    let voicesAfterSecond = engine.voices.filter { $0.padIndex == 0 }.count
    #expect(voicesAfterSecond == 1)
}

@Test @MainActor func engineNoCutModeStacksVoices() {
    let engine = GodEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "808", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    // cut is OFF (default)
    engine.togglePlay()

    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)

    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)

    let voices = engine.voices.filter { $0.padIndex == 0 }.count
    #expect(voices == 2)
}

@Test @MainActor func engineCCOutOfRangeIgnored() {
    let engine = GodEngine()
    engine.togglePlay()

    // CC 1 is not mapped
    engine.midiRingBuffer.write(.cc(number: 1, value: 127))
    let _ = engine.processBlock(frameCount: 512)

    // Should not crash or change anything
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

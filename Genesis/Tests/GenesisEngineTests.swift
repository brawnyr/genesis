import Testing
import Foundation
@testable import Genesis

private func activeVoiceCount(_ engine: GenesisEngine, pad: Int) -> Int {
    engine.voicePool.slots.filter { $0.active && $0.padIndex == pad }.count
}

private func totalActiveVoices(_ engine: GenesisEngine) -> Int {
    engine.voicePool.slots.filter { $0.active }.count
}

@Test @MainActor func engineActivePadTracking() {
    let engine = GenesisEngine()
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

    // CC 74 (reverb send knob) should target the active pad (3), not pad 0
    engine.midiRingBuffer.write(.cc(number: 74, value: 64))
    let _ = engine.processBlock(frameCount: 512)

    // Layer 3 reverb send should be ~0.5 (64/127), layer 0 should be unchanged at 0.0
    #expect(engine.audio.layers[3].reverbSend < 0.6)
    #expect(engine.audio.layers[3].reverbSend > 0.4)
    #expect(engine.audio.layers[0].reverbSend == 0.0)
}

@Test @MainActor func engineChokeChopsVoices() {
    let engine = GenesisEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "808", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.togglePlay()

    // First hit — should create 1 voice
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)
    #expect(activeVoiceCount(engine, pad: 0) == 1)

    // Second hit — choke should remove first, add new = still 1 voice
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)
    #expect(activeVoiceCount(engine, pad: 0) == 1)
}

@Test @MainActor func engineNoChokeStacksVoices() {
    let engine = GenesisEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "808", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.toggleChoke(pad: 0)  // turn OFF choke so voices stack
    engine.togglePlay()

    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)

    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)

    #expect(activeVoiceCount(engine, pad: 0) == 2)
}

@Test @MainActor func engineCCOutOfRangeIgnored() {
    let engine = GenesisEngine()
    engine.togglePlay()

    // CC 1 is not mapped
    engine.midiRingBuffer.write(.cc(number: 1, value: 127))
    let _ = engine.processBlock(frameCount: 512)

    let data = [Float](repeating: 1.0, count: 44100)
    let sample = Sample(name: "kick", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 127))
    let _ = engine.processBlock(frameCount: 512)

    if let voice = engine.voicePool.slots.first(where: { $0.active && $0.padIndex == 0 }) {
        #expect(voice.velocity > 0.99)
    } else {
        Issue.record("Expected voice for pad 0")
    }
}

@Test @MainActor func engineUndoLastClear() {
    let engine = GenesisEngine()
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
    let engine = GenesisEngine()
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
    let engine = GenesisEngine()
    engine.setMasterVolume(0.5)
    #expect(engine.audio.masterVolume == 0.5)

    engine.setMasterVolume(-0.5)
    #expect(engine.audio.masterVolume == 0.0)

    engine.setMasterVolume(2.0)
    #expect(engine.audio.masterVolume == 1.0)
}

@Test @MainActor func engineCC18SetsSwing() {
    let engine = GenesisEngine()
    engine.togglePlay()

    // CC 18 value 0 → swing 0.5 (straight)
    engine.midiRingBuffer.write(.cc(number: 18, value: 0))
    let _ = engine.processBlock(frameCount: 512)
    #expect(engine.audio.layers[0].swing == 0.5)

    // CC 18 value 127 → swing 1.0 (max: full sixteenth push)
    engine.midiRingBuffer.write(.cc(number: 18, value: 127))
    let _ = engine.processBlock(frameCount: 512)
    #expect(abs(engine.audio.layers[0].swing - 1.0) < 0.01)

    // CC 18 value 64 → swing ~0.75 (midpoint)
    engine.midiRingBuffer.write(.cc(number: 18, value: 64))
    let _ = engine.processBlock(frameCount: 512)
    #expect(engine.audio.layers[0].swing > 0.74)
    #expect(engine.audio.layers[0].swing < 0.76)
}

@Test @MainActor func engineSwingShiftsPlayback() {
    let engine = GenesisEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "hat", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.audio.activePadIndex = 0
    engine.togglePlay()

    let loopLen = engine.audio.loopLengthFrames
    let beatsPerLoop = engine.audio.barCount * Transport.beatsPerBar
    let sixteenth = SwingMath.sixteenthLength(loopLengthFrames: loopLen, beatsPerLoop: beatsPerLoop)

    // Place hit exactly at slot 1 (odd = will be swung)
    engine.audio.layers[0].addHit(at: sixteenth, velocity: 100)
    engine.audio.layers[0].hasNewHits = false

    // With no swing, hit triggers at frame = sixteenth
    engine.audio.layers[0].swing = 0.5
    engine.audio.position = sixteenth
    engine.voicePool.killAll()
    let _ = engine.processBlock(frameCount: 512)
    #expect(totalActiveVoices(engine) >= 1, "Hit should trigger at stored position with no swing")

    // With swing 0.75, hit should NOT trigger at stored position
    engine.audio.layers[0].swing = 0.75
    engine.audio.position = sixteenth
    engine.voicePool.killAll()
    let _ = engine.processBlock(frameCount: 512)

    // Now position at the actual swung location — swing 0.75 offsets by 0.5 * sixteenth
    let swungOffset = Int(roundf((0.75 - 0.5) * 2.0 * Float(sixteenth)))
    engine.audio.position = sixteenth + swungOffset
    engine.voicePool.killAll()
    let _ = engine.processBlock(frameCount: 512)
    #expect(totalActiveVoices(engine) >= 1, "Hit should trigger at swung position")
}

@Test @MainActor func engineSwingExpandedBackwardScan() {
    // Test that a hit stored BEFORE the block start triggers when swung INTO the block
    let engine = GenesisEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "hat", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.audio.activePadIndex = 0
    engine.togglePlay()

    let loopLen = engine.audio.loopLengthFrames
    let beatsPerLoop = engine.audio.barCount * Transport.beatsPerBar
    let sixteenth = SwingMath.sixteenthLength(loopLengthFrames: loopLen, beatsPerLoop: beatsPerLoop)

    // Place hit at slot 1 (odd)
    engine.audio.layers[0].addHit(at: sixteenth, velocity: 100)
    engine.audio.layers[0].swing = 0.75

    // Swing 0.75 offsets by 0.5 * sixteenth
    let swungOffset = Int(roundf((0.75 - 0.5) * 2.0 * Float(sixteenth)))

    // Position the block AFTER the stored hit but AT the swung position
    engine.audio.position = sixteenth + swungOffset - 10
    engine.voicePool.killAll()
    let _ = engine.processBlock(frameCount: 512)

    // The backward scan should find the hit and trigger it at the swung position
    #expect(totalActiveVoices(engine) >= 1, "Backward scan should catch hit swung into this block")
}

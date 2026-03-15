import Foundation
import Testing
@testable import Genesis

// MARK: - Voice pool exhaustion

@Test @MainActor func voicePoolExhaustionDropsSilently() {
    let engine = GenesisEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "pad", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.toggleChoke(pad: 0) // disable choke so voices stack
    engine.togglePlay()

    // Fill all 32 voice slots
    for _ in 0..<VoicePool.capacity {
        engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 127))
        let _ = engine.processBlock(frameCount: 128)
    }

    let activeCount = engine.voicePool.slots.filter { $0.active }.count
    #expect(activeCount == VoicePool.capacity, "All 32 slots should be active")

    // 33rd note should be silently dropped — no crash, no corruption
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 127))
    let (left, right) = engine.processBlock(frameCount: 128)

    // Output should still be valid (finite, non-NaN)
    let allFinite = left.allSatisfy { $0.isFinite } && right.allSatisfy { $0.isFinite }
    #expect(allFinite, "Output must remain finite when voice pool is full")
    #expect(engine.voicePool.slots.filter { $0.active }.count == VoicePool.capacity)
}

// MARK: - Full voice pool + reverb + filters under sustained load

@Test @MainActor func fullLoadRenderingStability() {
    let engine = GenesisEngine()

    // Load 8 different samples across pads
    for i in 0..<8 {
        let freq = Float(80 + i * 200) // 80Hz to 1480Hz
        var data = [Float](repeating: 0, count: 44100)
        for j in 0..<44100 {
            data[j] = 0.8 * sin(2.0 * .pi * freq * Float(j) / 44100.0)
        }
        let sample = Sample(name: "tone_\(i)", left: data, right: data, sampleRate: 44100)
        engine.padBank.assign(sample: sample, toPad: i)
    }

    // Disable choke on all pads, enable reverb + filters
    for i in 0..<8 {
        engine.toggleChoke(pad: i)
        engine.setLayerVolume(i, volume: 0.25)
    }
    engine.togglePlay()

    // Set reverb sends and filters via audio state directly (simulating CC input)
    engine.audio.layers[0].reverbSend = 0.8
    engine.audio.layers[1].reverbSend = 0.5
    engine.audio.layers[2].hpCutoff = 500
    engine.audio.layers[3].lpCutoff = 2000
    engine.audio.layers[4].reverbSend = 1.0
    engine.audio.layers[4].hpCutoff = 200
    engine.audio.layers[5].lpCutoff = 5000
    engine.audio.layers[5].reverbSend = 0.3

    // Fill voice pool: 4 voices per pad across 8 pads = 32 voices
    for pad in 0..<8 {
        let note = 36 + pad
        for _ in 0..<4 {
            engine.midiRingBuffer.write(.noteOn(note: note, velocity: 127))
            let _ = engine.processBlock(frameCount: 128)
        }
    }

    let activeCount = engine.voicePool.slots.filter { $0.active }.count
    #expect(activeCount == VoicePool.capacity, "All 32 voice slots should be filled")

    // Now render 100 blocks (~0.3 seconds) at full load and verify stability
    for block in 0..<100 {
        let (left, right) = engine.processBlock(frameCount: 128)

        let allFiniteL = left.allSatisfy { $0.isFinite }
        let allFiniteR = right.allSatisfy { $0.isFinite }
        #expect(allFiniteL && allFiniteR, "Block \(block): output must be finite under full load")

        let peakL = left.map { abs($0) }.max() ?? 0
        let peakR = right.map { abs($0) }.max() ?? 0
        // No single block should produce absurd values (>10.0 would indicate a feedback loop)
        #expect(peakL < 10.0, "Block \(block): left peak \(peakL) is unreasonably high")
        #expect(peakR < 10.0, "Block \(block): right peak \(peakR) is unreasonably high")
    }
}

// MARK: - Reverb tail stability (denormal prevention)

@Test func reverbTailDecaysCleanly() {
    let reverb = ReverbProcessor()
    let blockSize = 128

    // Feed a single impulse into the reverb
    var impulseL = [Float](repeating: 0, count: blockSize)
    var impulseR = [Float](repeating: 0, count: blockSize)
    impulseL[0] = 1.0
    impulseR[0] = 1.0
    var outL = [Float](repeating: 0, count: blockSize)
    var outR = [Float](repeating: 0, count: blockSize)

    impulseL.withUnsafeBufferPointer { sendL in
        impulseR.withUnsafeBufferPointer { sendR in
            reverb.process(sendL: sendL.baseAddress!, sendR: sendR.baseAddress!,
                          intoLeft: &outL, intoRight: &outR, count: blockSize)
        }
    }

    // Now feed silence for ~5 seconds (enough for full tail decay at feedback=0.84)
    let silentBlocks = Int(44100.0 * 5.0 / Double(blockSize))
    let silence = [Float](repeating: 0, count: blockSize)
    var peakAt1s: Float = 0
    var peakAt4s: Float = 0
    let blocksAt1s = Int(44100.0 / Double(blockSize))
    let blocksAt4s = Int(44100.0 * 4.0 / Double(blockSize))

    for block in 0..<silentBlocks {
        outL = [Float](repeating: 0, count: blockSize)
        outR = [Float](repeating: 0, count: blockSize)

        silence.withUnsafeBufferPointer { sendL in
            silence.withUnsafeBufferPointer { sendR in
                reverb.process(sendL: sendL.baseAddress!, sendR: sendR.baseAddress!,
                              intoLeft: &outL, intoRight: &outR, count: blockSize)
            }
        }

        let peak = max(
            outL.map { abs($0) }.max() ?? 0,
            outR.map { abs($0) }.max() ?? 0
        )

        // Every sample must be finite (no NaN/Inf from denormal accumulation)
        let allFinite = outL.allSatisfy { $0.isFinite } && outR.allSatisfy { $0.isFinite }
        #expect(allFinite, "Reverb tail block \(block): all samples must be finite")

        if block == blocksAt1s { peakAt1s = peak }
        if block == blocksAt4s { peakAt4s = peak }
    }

    // Tail should decay significantly over time
    #expect(peakAt4s < peakAt1s, "Reverb tail at 4s should be quieter than at 1s")
    #expect(peakAt4s < 1e-3, "Reverb tail should be negligible after 4 seconds, got \(peakAt4s)")
}

// MARK: - Rapid choke/retrigger stability

@Test @MainActor func rapidChokeRetriggerProducesCleanOutput() {
    let engine = GenesisEngine()
    let data = [Float](repeating: 0.9, count: 44100)
    let sample = Sample(name: "hit", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    // Choke ON (default) — each hit kills previous voice
    engine.togglePlay()

    // Rapid-fire 200 hits (simulating fast finger drumming)
    for _ in 0..<200 {
        engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 127))
        let (left, right) = engine.processBlock(frameCount: 128)

        let allFinite = left.allSatisfy { $0.isFinite } && right.allSatisfy { $0.isFinite }
        #expect(allFinite, "Output must stay finite during rapid retrigger")

        // Check for hard discontinuities (clicks) — declick should prevent jumps > 0.1
        for i in 1..<left.count {
            let jump = abs(left[i] - left[i-1])
            #expect(jump < 0.5, "Sample-to-sample jump of \(jump) suggests a click at frame \(i)")
        }
    }

    // Should have exactly 1 active voice (last hit, previous ones declicked and finished)
    let active = engine.voicePool.slots.filter { $0.active }.count
    #expect(active == 1, "After rapid choke retrigger, only the last voice should remain active")
}

// MARK: - Multi-pad simultaneous hit stability

@Test @MainActor func allPadsSimultaneousHit() {
    let engine = GenesisEngine()

    // Load all 8 pads with distinct samples
    for i in 0..<PadBank.padCount {
        let freq = Float(60 + i * 150)
        var data = [Float](repeating: 0, count: 44100)
        for j in 0..<44100 {
            data[j] = 0.7 * sin(2.0 * .pi * freq * Float(j) / 44100.0)
        }
        let sample = Sample(name: "pad\(i)", left: data, right: data, sampleRate: 44100)
        engine.padBank.assign(sample: sample, toPad: i)
    }
    engine.togglePlay()

    // Hit all 8 pads in a single block
    for i in 0..<PadBank.padCount {
        engine.midiRingBuffer.write(.noteOn(note: 36 + i, velocity: 127))
    }
    let (left, right) = engine.processBlock(frameCount: 4096)

    let stats = left.map { abs($0) }
    let peak = stats.max() ?? 0

    #expect(left.allSatisfy { $0.isFinite }, "All left samples must be finite")
    #expect(right.allSatisfy { $0.isFinite }, "All right samples must be finite")
    #expect(peak > 0, "Output should not be silent when all pads are hit")

    // 8 voices should be active
    let activeVoices = engine.voicePool.slots.filter { $0.active }.count
    #expect(activeVoices == PadBank.padCount, "All \(PadBank.padCount) pads should have active voices")
}

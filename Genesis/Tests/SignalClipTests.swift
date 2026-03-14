// SignalClipTests.swift — Pad emulator + signal listener for diagnosing clipping
//
// Emulates the full signal path: sample → voice fill → mixer → reverb → master volume → output
// Measures peak levels at every stage so you can see exactly where and why clipping occurs.

import Foundation
import Testing
@testable import Genesis

// MARK: - Signal measurement helpers

/// Measures peak, RMS, and clipping stats for a buffer
struct SignalStats: CustomStringConvertible {
    let peak: Float
    let rms: Float
    let peakDb: Float
    let rmsDb: Float
    let clippedSamples: Int      // samples exceeding ±1.0
    let totalSamples: Int
    let clipPercent: Float

    init(buffer: [Float]) {
        var maxAbs: Float = 0
        var sumSq: Float = 0
        var clipped = 0
        for s in buffer {
            let a = abs(s)
            maxAbs = max(maxAbs, a)
            sumSq += s * s
            if a > 1.0 { clipped += 1 }
        }
        peak = maxAbs
        rms = buffer.isEmpty ? 0 : sqrt(sumSq / Float(buffer.count))
        peakDb = maxAbs > 0 ? 20 * log10(maxAbs) : -.infinity
        rmsDb = rms > 0 ? 20 * log10(rms) : -.infinity
        clippedSamples = clipped
        totalSamples = buffer.count
        clipPercent = buffer.isEmpty ? 0 : Float(clipped) / Float(buffer.count) * 100
    }

    var description: String {
        let clipInfo = clippedSamples > 0 ? " ⚠️ \(clippedSamples) clipped (\(String(format: "%.1f", clipPercent))%)" : " ✓ clean"
        return "peak: \(String(format: "%.4f", peak)) (\(String(format: "%.1f", peakDb))dB)  rms: \(String(format: "%.4f", rms)) (\(String(format: "%.1f", rmsDb))dB)\(clipInfo)"
    }
}

/// Merges L+R into a combined stereo stats report
struct StereoStats: CustomStringConvertible {
    let left: SignalStats
    let right: SignalStats
    let combinedPeak: Float
    let combinedPeakDb: Float

    init(left: [Float], right: [Float]) {
        self.left = SignalStats(buffer: left)
        self.right = SignalStats(buffer: right)
        combinedPeak = max(self.left.peak, self.right.peak)
        combinedPeakDb = combinedPeak > 0 ? 20 * log10(combinedPeak) : -.infinity
    }

    var isClipping: Bool { left.clippedSamples > 0 || right.clippedSamples > 0 }

    var description: String {
        "L: \(left)\nR: \(right)\nStereo peak: \(String(format: "%.4f", combinedPeak)) (\(String(format: "%.1f", combinedPeakDb))dB)"
    }
}

// MARK: - Test sample generators

/// Generate a sine wave sample at a given frequency and peak level
func makeSine(hz: Float, peak: Float = 1.0, durationFrames: Int = 44100, sampleRate: Float = 44100) -> Sample {
    var data = [Float](repeating: 0, count: durationFrames)
    for i in 0..<durationFrames {
        data[i] = peak * sin(2.0 * .pi * hz * Float(i) / sampleRate)
    }
    return Sample(name: "sine_\(Int(hz))hz", left: data, right: data, sampleRate: Double(sampleRate))
}

/// Generate a loud transient sample (click/kick style) — peaks above 1.0 like real-world samples
func makeTransient(peak: Float = 0.95, decayMs: Float = 50, durationFrames: Int = 44100) -> Sample {
    var data = [Float](repeating: 0, count: durationFrames)
    let decaySamples = Int(decayMs * 44.1)
    for i in 0..<min(decaySamples, durationFrames) {
        let env = peak * exp(-5.0 * Float(i) / Float(decaySamples))
        data[i] = env * sin(2.0 * .pi * 60.0 * Float(i) / 44100.0)  // 60Hz sub
        data[i] += env * 0.5 * sin(2.0 * .pi * 3000.0 * Float(i) / 44100.0)  // click transient
    }
    return Sample(name: "transient_\(peak)", left: data, right: data, sampleRate: 44100)
}

/// Generate a hot sample that peaks above 1.0 (common with Splice samples)
func makeHotSample(peak: Float = 1.2) -> Sample {
    var data = [Float](repeating: 0, count: 44100)
    for i in 0..<44100 {
        let env = peak * exp(-3.0 * Float(i) / 44100.0)
        data[i] = env * sin(2.0 * .pi * 80.0 * Float(i) / 44100.0)
    }
    return Sample(name: "hot_\(peak)", left: data, right: data, sampleRate: 44100)
}

// MARK: - Pad emulator: single voice, full signal path

/// Runs a single voice through the full signal chain and reports levels at each stage
func emulateVoice(
    sample: Sample,
    velocity: Float = 1.0,
    volume: Float = 0.25,
    pan: Float = 0.5,
    hpCutoff: Float = Layer.hpBypassFrequency,
    lpCutoff: Float = Layer.lpBypassFrequency,
    masterVolume: Float = 1.0,
    frameCount: Int? = nil
) -> (raw: SignalStats, postVoice: StereoStats, postMaster: StereoStats) {
    let count = frameCount ?? sample.frameCount
    let sr = Float(Transport.sampleRate)

    // Stage 0: Raw sample
    let rawStats = SignalStats(buffer: Array(sample.left.prefix(count)))

    // Stage 1: Voice fill (velocity * volume → filter → pan → accumulate)
    var voice = Voice()
    voice.start(sample: sample, velocity: velocity, padIndex: 0)

    let hpCoeffs = hpCutoff <= 21 ? BiquadCoefficients.bypass : BiquadCoefficients.highPass(cutoff: hpCutoff, sampleRate: sr)
    let lpCoeffs = lpCutoff >= 19999 ? BiquadCoefficients.bypass : BiquadCoefficients.lowPass(cutoff: lpCutoff, sampleRate: sr)

    var left = [Float](repeating: 0, count: count)
    var right = [Float](repeating: 0, count: count)
    let _ = voice.fill(intoLeft: &left, right: &right, count: count,
                        pan: pan, volume: volume, hpCoeffs: hpCoeffs, lpCoeffs: lpCoeffs)
    let postVoice = StereoStats(left: left, right: right)

    // Stage 2: Master volume
    var masterL = left
    var masterR = right
    for i in 0..<count {
        masterL[i] *= masterVolume
        masterR[i] *= masterVolume
    }
    let postMaster = StereoStats(left: masterL, right: masterR)

    return (rawStats, postVoice, postMaster)
}

// MARK: - Multi-pad stacking emulator

/// Stacks multiple voices (like hitting several pads at once) and measures combined output
func emulateStack(
    samples: [(sample: Sample, velocity: Float, volume: Float, pan: Float)],
    reverbSend: Float = 0.0,
    masterVolume: Float = 1.0,
    frameCount: Int = 4096
) -> (preMaster: StereoStats, postMaster: StereoStats, postReverb: StereoStats) {
    let sr = Float(Transport.sampleRate)
    var outL = [Float](repeating: 0, count: frameCount)
    var outR = [Float](repeating: 0, count: frameCount)
    var revL = [Float](repeating: 0, count: frameCount)
    var revR = [Float](repeating: 0, count: frameCount)

    for (idx, entry) in samples.enumerated() {
        var voice = Voice()
        voice.start(sample: entry.sample, velocity: entry.velocity, padIndex: idx)

        if reverbSend > 0.001 {
            var scratchL = [Float](repeating: 0, count: frameCount)
            var scratchR = [Float](repeating: 0, count: frameCount)
            let _ = voice.fill(intoLeft: &scratchL, right: &scratchR, count: frameCount,
                               pan: entry.pan, volume: entry.volume, hpCoeffs: .bypass, lpCoeffs: .bypass)
            for i in 0..<frameCount {
                outL[i] += scratchL[i]
                outR[i] += scratchR[i]
                revL[i] += scratchL[i] * reverbSend
                revR[i] += scratchR[i] * reverbSend
            }
        } else {
            let _ = voice.fill(intoLeft: &outL, right: &outR, count: frameCount,
                               pan: entry.pan, volume: entry.volume, hpCoeffs: .bypass, lpCoeffs: .bypass)
        }
    }

    let preMaster = StereoStats(left: outL, right: outR)

    // Reverb pass
    let reverb = ReverbProcessor()
    revL.withUnsafeBufferPointer { sendLPtr in
        revR.withUnsafeBufferPointer { sendRPtr in
            reverb.process(sendL: sendLPtr.baseAddress!, sendR: sendRPtr.baseAddress!,
                          intoLeft: &outL, intoRight: &outR, count: frameCount)
        }
    }
    let postReverb = StereoStats(left: outL, right: outR)

    // Master volume
    var masterL = outL
    var masterR = outR
    for i in 0..<frameCount {
        masterL[i] *= masterVolume
        masterR[i] *= masterVolume
    }
    let postMaster = StereoStats(left: masterL, right: masterR)

    return (preMaster, postMaster, postReverb)
}

// MARK: - Tests

@Test func singleVoiceSignalLevels() {
    // A normal sample at default volume — should NOT clip
    let sample = makeSine(hz: 440, peak: 0.9)
    let (raw, post, master) = emulateVoice(sample: sample, velocity: 1.0, volume: 0.25, masterVolume: 1.0)

    print("\n=== SINGLE VOICE (sine 440Hz, peak 0.9) ===")
    print("Raw sample:     \(raw)")
    print("Post voice:     \(post)")
    print("Post master:    \(master)")

    // Default volume 0.25 means signal is 0.9 * 1.0 * 0.25 = 0.225
    #expect(!master.isClipping, "Single voice at default volume should not clip")
    #expect(master.combinedPeak < 0.3, "Peak should be well under 1.0")
}

@Test func hotSampleClipCheck() {
    // A hot sample (peaks at 1.2) at various volumes
    let hot = makeHotSample(peak: 1.2)
    let rawStats = SignalStats(buffer: hot.left)

    print("\n=== HOT SAMPLE (peak 1.2 = +1.6dB) ===")
    print("Raw: \(rawStats)")

    // At default volume 0.25
    let (_, postDefault, masterDefault) = emulateVoice(sample: hot, volume: 0.25, masterVolume: 1.0)
    print("Vol 0.25:       \(masterDefault)")
    #expect(!masterDefault.isClipping, "Hot sample at 0.25 vol should not clip")

    // At full volume 1.0
    let (_, postFull, masterFull) = emulateVoice(sample: hot, volume: 1.0, masterVolume: 1.0)
    print("Vol 1.0:        \(masterFull)")
    // This WILL clip — 1.2 * 1.0 * 1.0 = 1.2
    if masterFull.isClipping {
        print("  → CLIPPING: hot sample at full volume exceeds ±1.0")
    }

    // At full volume + master 0.8
    let (_, _, masterReduced) = emulateVoice(sample: hot, volume: 1.0, masterVolume: 0.8)
    print("Vol 1.0 / M 0.8: \(masterReduced)")
}

@Test func multiPadStackClipCheck() {
    // Stack 4 pads hitting simultaneously — common scenario
    let kick = makeTransient(peak: 0.95, decayMs: 100)
    let hat = makeSine(hz: 8000, peak: 0.7, durationFrames: 4096)
    let snare = makeTransient(peak: 0.85, decayMs: 60)
    let bass = makeSine(hz: 80, peak: 0.9, durationFrames: 4096)

    let pads: [(sample: Sample, velocity: Float, volume: Float, pan: Float)] = [
        (kick,  1.0, 0.25, 0.5),   // kick — center
        (hat,   0.8, 0.25, 0.6),   // hat — slightly right
        (snare, 1.0, 0.25, 0.5),   // snare — center
        (bass,  1.0, 0.25, 0.5),   // bass — center
    ]

    let (pre, post, _) = emulateStack(samples: pads, masterVolume: 1.0)

    print("\n=== 4-PAD STACK (kick+hat+snare+bass, default vol 0.25) ===")
    print("Pre master:  \(pre)")
    print("Post master: \(post)")
    #expect(!post.isClipping, "4 pads at default volume should not clip")

    // Now at higher volumes
    let loudPads = pads.map { ($0.sample, $0.velocity, Float(0.7), $0.pan) }
    let (preLoud, postLoud, _) = emulateStack(samples: loudPads, masterVolume: 1.0)

    print("\n=== 4-PAD STACK (same, vol 0.7) ===")
    print("Pre master:  \(preLoud)")
    print("Post master: \(postLoud)")
    if postLoud.isClipping {
        print("  → CLIPPING at vol 0.7 with 4 simultaneous pads")
    }

    // Full volume stack
    let maxPads = pads.map { ($0.sample, $0.velocity, Float(1.0), $0.pan) }
    let (preMax, postMax, _) = emulateStack(samples: maxPads, masterVolume: 1.0)

    print("\n=== 4-PAD STACK (same, vol 1.0) ===")
    print("Pre master:  \(preMax)")
    print("Post master: \(postMax)")
    if postMax.isClipping {
        print("  → CLIPPING at full volume with 4 simultaneous pads")
    }
}

@Test func reverbGainAccumulation() {
    // Test if reverb adds enough gain to cause clipping
    let sample = makeSine(hz: 200, peak: 0.8)
    let pads: [(sample: Sample, velocity: Float, volume: Float, pan: Float)] = [
        (sample, 1.0, 0.5, 0.5),
    ]

    // No reverb
    let (preDry, postDry, _) = emulateStack(samples: pads, reverbSend: 0.0, masterVolume: 1.0)
    // Full reverb
    let (preWet, postWet, postRev) = emulateStack(samples: pads, reverbSend: 1.0, masterVolume: 1.0)

    print("\n=== REVERB GAIN (single voice, vol 0.5, 200Hz sine) ===")
    print("Dry:         \(postDry)")
    print("Wet (100%):  \(postWet)")
    print("Post reverb: \(postRev)")

    let gainFromReverb = postRev.combinedPeak - preDry.combinedPeak
    print("Reverb adds: \(String(format: "%.4f", gainFromReverb)) peak (\(String(format: "%.1f", 20*log10(postRev.combinedPeak / preDry.combinedPeak)))dB)")
}

@Test func velocityStackingClipCheck() {
    // Same pad hit 8 times rapidly (no choke) — worst case voice stacking
    let sample = makeSine(hz: 200, peak: 0.9, durationFrames: 44100)
    var pads: [(sample: Sample, velocity: Float, volume: Float, pan: Float)] = []
    for _ in 0..<8 {
        pads.append((sample, 1.0, 0.25, 0.5))
    }

    let (_, post, _) = emulateStack(samples: pads, masterVolume: 1.0)

    print("\n=== 8x VOICE STACK (same sample, no choke, vol 0.25) ===")
    print("Post master: \(post)")
    // 8 voices * 0.9 * 0.25 * pan_scale ≈ 8 * 0.159 = 1.27 — will clip!
    if post.isClipping {
        print("  → CLIPPING: 8 stacked voices exceed ±1.0 even at default volume")
        // Find the max safe voice count
        for n in 1...8 {
            let subset = Array(pads.prefix(n))
            let (_, postN, _) = emulateStack(samples: subset, masterVolume: 1.0)
            if postN.isClipping {
                print("  → Clipping starts at \(n) simultaneous voices")
                break
            }
        }
    }
}

@Test func findClipThreshold() {
    // Binary search for the volume that causes clipping with typical 4-pad stack
    let kick = makeTransient(peak: 0.95, decayMs: 100)
    let hat = makeSine(hz: 8000, peak: 0.7, durationFrames: 4096)
    let snare = makeTransient(peak: 0.85, decayMs: 60)
    let bass = makeSine(hz: 80, peak: 0.9, durationFrames: 4096)

    print("\n=== CLIP THRESHOLD SEARCH (4-pad stack) ===")
    var lo: Float = 0.1
    var hi: Float = 1.0
    while hi - lo > 0.01 {
        let mid = (lo + hi) / 2
        let pads: [(sample: Sample, velocity: Float, volume: Float, pan: Float)] = [
            (kick, 1.0, mid, 0.5), (hat, 0.8, mid, 0.6),
            (snare, 1.0, mid, 0.5), (bass, 1.0, mid, 0.5),
        ]
        let (_, post, _) = emulateStack(samples: pads, masterVolume: 1.0)
        if post.isClipping {
            hi = mid
        } else {
            lo = mid
        }
    }
    print("4-pad stack clips at volume ≈ \(String(format: "%.2f", hi)) (\(String(format: "%.1f", 20*log10(hi)))dB)")
    print("Safe headroom at default 0.25: \(String(format: "%.1f", 20*log10(hi / 0.25)))dB above default")

    // Same but with reverb
    lo = 0.1; hi = 1.0
    while hi - lo > 0.01 {
        let mid = (lo + hi) / 2
        let pads: [(sample: Sample, velocity: Float, volume: Float, pan: Float)] = [
            (kick, 1.0, mid, 0.5), (hat, 0.8, mid, 0.6),
            (snare, 1.0, mid, 0.5), (bass, 1.0, mid, 0.5),
        ]
        let (_, post, _) = emulateStack(samples: pads, reverbSend: 0.5, masterVolume: 1.0)
        if post.isClipping {
            hi = mid
        } else {
            lo = mid
        }
    }
    print("With 50% reverb: clips at volume ≈ \(String(format: "%.2f", hi))")
}

@Test func fullEngineClipDiagnostic() {
    // Run a full engine processBlock with multiple pads loaded and measure output
    let engine = GenesisEngine()
    let kick = makeTransient(peak: 0.95, decayMs: 100)
    let hat = makeSine(hz: 8000, peak: 0.7)
    let snare = makeTransient(peak: 0.85, decayMs: 60)
    let bass = makeSine(hz: 80, peak: 0.9)

    engine.padBank.assign(sample: kick, toPad: 0)
    engine.padBank.assign(sample: hat, toPad: 1)
    engine.padBank.assign(sample: snare, toPad: 2)
    engine.padBank.assign(sample: bass, toPad: 3)
    engine.togglePlay()

    // Hit all 4 pads simultaneously via MIDI
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 127))  // kick
    engine.midiRingBuffer.write(.noteOn(note: 37, velocity: 100))  // hat
    engine.midiRingBuffer.write(.noteOn(note: 38, velocity: 127))  // snare
    engine.midiRingBuffer.write(.noteOn(note: 39, velocity: 127))  // bass

    let (left, right) = engine.processBlock(frameCount: 4096)
    let stats = StereoStats(left: left, right: right)

    print("\n=== FULL ENGINE (4 pads, MIDI velocity, default settings) ===")
    print("Output: \(stats)")
    if stats.isClipping {
        print("  → Engine output clips with 4 simultaneous pads at default volume")
    } else {
        print("  → Clean output at default settings")
    }

    // Now crank volumes to 1.0
    for i in 0..<4 {
        engine.setLayerVolume(i, volume: 1.0)
    }
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 127))
    engine.midiRingBuffer.write(.noteOn(note: 37, velocity: 127))
    engine.midiRingBuffer.write(.noteOn(note: 38, velocity: 127))
    engine.midiRingBuffer.write(.noteOn(note: 39, velocity: 127))

    let (left2, right2) = engine.processBlock(frameCount: 4096)
    let stats2 = StereoStats(left: left2, right: right2)

    print("\n=== FULL ENGINE (4 pads, all vol 1.0) ===")
    print("Output: \(stats2)")
    if stats2.isClipping {
        print("  → CLIPPING at full volume — peak \(String(format: "%.2f", stats2.combinedPeak))x over unity")
    }
}

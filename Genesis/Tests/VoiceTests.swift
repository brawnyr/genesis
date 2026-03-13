import Foundation
import Testing
@testable import Genesis

@Test func voiceWithLowPassFilter() {
    let sampleRate: Float = 44100
    let frameCount = 4410
    var data = [Float](repeating: 0, count: frameCount)
    for i in 0..<frameCount {
        data[i] = sin(2.0 * .pi * 10000.0 * Float(i) / sampleRate)
    }
    let sample = Sample(name: "test", left: data, right: data, sampleRate: 44100)
    var voice = Voice()
    voice.start(sample: sample, velocity: 1.0, padIndex: 0)

    var left = [Float](repeating: 0, count: frameCount)
    var right = [Float](repeating: 0, count: frameCount)
    let lpCoeffs = BiquadCoefficients.lowPass(cutoff: 100, sampleRate: sampleRate)
    let (_, peak) = voice.fill(intoLeft: &left, right: &right, count: frameCount,
                                pan: 0.5, volume: 1.0, hpCoeffs: .bypass, lpCoeffs: lpCoeffs)
    #expect(peak < 0.1)
}

@Test func voiceWithHighPassFilter() {
    let sampleRate: Float = 44100
    let frameCount = 4410
    // 100Hz sine — should be killed by a 5kHz HP
    var data = [Float](repeating: 0, count: frameCount)
    for i in 0..<frameCount {
        data[i] = sin(2.0 * .pi * 100.0 * Float(i) / sampleRate)
    }
    let sample = Sample(name: "test", left: data, right: data, sampleRate: 44100)
    var voice = Voice()
    voice.start(sample: sample, velocity: 1.0, padIndex: 0)

    var left = [Float](repeating: 0, count: frameCount)
    var right = [Float](repeating: 0, count: frameCount)
    let hpCoeffs = BiquadCoefficients.highPass(cutoff: 5000, sampleRate: sampleRate)
    let (_, _) = voice.fill(intoLeft: &left, right: &right, count: frameCount,
                             pan: 0.5, volume: 1.0, hpCoeffs: hpCoeffs, lpCoeffs: .bypass)
    // Check steady-state output (skip first 500 frames for transient)
    let steadyPeak = left[500..<frameCount].map { abs($0) }.max() ?? 0
    #expect(steadyPeak < 0.05)
}

@Test func voicePanLaw() {
    // Use enough samples so interpolation converges to target pan
    let frameCount = 64
    let data = [Float](repeating: 1.0, count: frameCount)
    let sample = Sample(name: "test", left: data, right: data, sampleRate: 44100)

    // Pan hard left — pre-set prevPan to target so no ramp
    var voiceL = Voice()
    voiceL.start(sample: sample, velocity: 1.0, padIndex: 0)
    voiceL.prevPanL = cos(0.0 * .pi / 2.0)  // 1.0
    voiceL.prevPanR = sin(0.0 * .pi / 2.0)  // 0.0
    var leftL = [Float](repeating: 0, count: frameCount)
    var rightL = [Float](repeating: 0, count: frameCount)
    let (_, _) = voiceL.fill(intoLeft: &leftL, right: &rightL, count: frameCount,
                              pan: 0.0, volume: 1.0, hpCoeffs: .bypass, lpCoeffs: .bypass)
    #expect(leftL[0] > 0.9)
    #expect(rightL[0] < 0.1)

    // Pan hard right
    var voiceR = Voice()
    voiceR.start(sample: sample, velocity: 1.0, padIndex: 0)
    voiceR.prevPanL = cos(1.0 * .pi / 2.0)  // 0.0
    voiceR.prevPanR = sin(1.0 * .pi / 2.0)  // 1.0
    var leftR = [Float](repeating: 0, count: frameCount)
    var rightR = [Float](repeating: 0, count: frameCount)
    let (_, _) = voiceR.fill(intoLeft: &leftR, right: &rightR, count: frameCount,
                              pan: 1.0, volume: 1.0, hpCoeffs: .bypass, lpCoeffs: .bypass)
    #expect(leftR[0] < 0.1)
    #expect(rightR[0] > 0.9)
}

@Test func voiceAddsToExistingBuffer() {
    let frameCount = 64
    let data = [Float](repeating: 1.0, count: frameCount)
    let sample = Sample(name: "test", left: data, right: data, sampleRate: 44100)
    var voice = Voice()
    voice.start(sample: sample, velocity: 1.0, padIndex: 0)

    // Pre-fill buffers with 0.5
    var left = [Float](repeating: 0.5, count: frameCount)
    var right = [Float](repeating: 0.5, count: frameCount)
    let (_, _) = voice.fill(intoLeft: &left, right: &right, count: frameCount,
                             pan: 0.5, volume: 1.0, hpCoeffs: .bypass, lpCoeffs: .bypass)
    // Voice should ADD to existing values, not replace
    // Last sample should be fully converged to target pan
    let scale: Float = cos(0.5 * .pi / 2.0)
    let lastIdx = frameCount - 1
    #expect(abs(left[lastIdx] - (0.5 + scale)) < 0.02)
}

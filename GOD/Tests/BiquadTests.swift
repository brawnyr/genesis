import Testing
@testable import GOD
import Foundation

@Test func biquadStateStartsAtZero() {
    let state = BiquadState()
    #expect(state.z1 == 0)
    #expect(state.z2 == 0)
}

@Test func lowPassCoefficientsAtNyquist() {
    // LP at 20kHz with 44100 sample rate should pass signal through
    let coeffs = BiquadCoefficients.lowPass(cutoff: 20000, sampleRate: 44100)
    var state = BiquadState()
    // Send an impulse
    let output = biquadProcessSample(1.0, coeffs: coeffs, state: &state)
    #expect(output > 0.5)
}

@Test func highPassCoefficientsAtMinFreq() {
    // HP at 20Hz should block DC — after 1000 samples of 1.0, output should be near zero
    let coeffs = BiquadCoefficients.highPass(cutoff: 20, sampleRate: 44100)
    var state = BiquadState()
    var lastOutput: Float = 0
    for _ in 0..<10000 {
        lastOutput = biquadProcessSample(1.0, coeffs: coeffs, state: &state)
    }
    #expect(abs(lastOutput) < 0.1)
}

@Test func lowPassRemovesHighFrequency() {
    // LP at 100Hz should kill a 10kHz sine — peak < 0.05 after transient
    let coeffs = BiquadCoefficients.lowPass(cutoff: 100, sampleRate: 44100)
    var state = BiquadState()
    let freq: Float = 10000
    let sampleRate: Float = 44100
    // Run 2000 samples to get past transient, then measure peak over next 1000
    for i in 0..<2000 {
        let sample = sin(2.0 * Float.pi * freq * Float(i) / sampleRate)
        _ = biquadProcessSample(sample, coeffs: coeffs, state: &state)
    }
    var peak: Float = 0
    for i in 2000..<3000 {
        let sample = sin(2.0 * Float.pi * freq * Float(i) / sampleRate)
        let output = biquadProcessSample(sample, coeffs: coeffs, state: &state)
        peak = max(peak, abs(output))
    }
    #expect(peak < 0.05)
}

@Test func highPassRemovesLowFrequency() {
    // HP at 5kHz should kill a 100Hz sine — peak < 0.05 after transient
    let coeffs = BiquadCoefficients.highPass(cutoff: 5000, sampleRate: 44100)
    var state = BiquadState()
    let freq: Float = 100
    let sampleRate: Float = 44100
    // Run 2000 samples to get past transient, then measure peak over next 1000
    for i in 0..<2000 {
        let sample = sin(2.0 * Float.pi * freq * Float(i) / sampleRate)
        _ = biquadProcessSample(sample, coeffs: coeffs, state: &state)
    }
    var peak: Float = 0
    for i in 2000..<3000 {
        let sample = sin(2.0 * Float.pi * freq * Float(i) / sampleRate)
        let output = biquadProcessSample(sample, coeffs: coeffs, state: &state)
        peak = max(peak, abs(output))
    }
    #expect(peak < 0.05)
}

@Test func ccToFrequencyMapping() {
    let f0 = ccToFrequency(0)
    let f64 = ccToFrequency(64)
    let f127 = ccToFrequency(127)
    // cc=0 → ~20Hz
    #expect(abs(f0 - 20.0) < 1.0)
    // cc=64 → mid range (between 20 and 20000)
    #expect(f64 > 200)
    #expect(f64 < 5000)
    // cc=127 → ~20kHz
    #expect(abs(f127 - 20000.0) < 100.0)
}

import Testing
@testable import Genesis
import Foundation

@Test func bypassPassesSignalThrough() {
    let coeffs = BiquadCoefficients.bypass
    var state = BiquadState()
    for i in 0..<100 {
        let input = sin(2.0 * Float.pi * Float(i) / 44.1)
        let output = biquadProcessSample(input, coeffs: coeffs, state: &state)
        #expect(abs(output - input) < 0.0001)
    }
}

@Test func lowPassRemovesHighFrequency() {
    // LP at 100Hz should kill a 10kHz sine — peak < 0.05 after transient
    let coeffs = BiquadCoefficients.lowPass(cutoff: 100, sampleRate: 44100)
    var state = BiquadState()
    let freq: Float = 10000
    let sampleRate: Float = 44100
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

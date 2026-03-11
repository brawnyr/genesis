import Foundation

struct Voice {
    let sample: Sample
    let velocity: Float
    var padIndex: Int = -1
    var position: Int = 0

    // Per-voice filter state (separate L/R for stereo independence)
    var hpStateL = BiquadState()
    var hpStateR = BiquadState()
    var lpStateL = BiquadState()
    var lpStateR = BiquadState()

    /// Mixes this voice into stereo buffers with filtering and panning.
    /// Returns (finished, peak).
    mutating func fill(intoLeft left: inout [Float], right: inout [Float], count: Int,
                       pan: Float, volume: Float, hpCoeffs: BiquadCoefficients, lpCoeffs: BiquadCoefficients
    ) -> (finished: Bool, peak: Float) {
        let remaining = sample.frameCount - position
        let toWrite = min(count, remaining)
        var peak: Float = 0

        let gain = velocity * volume
        let panL = cos(pan * .pi / 2.0)
        let panR = sin(pan * .pi / 2.0)

        for i in 0..<toWrite {
            var l = sample.left[position + i] * gain
            var r = sample.right[position + i] * gain

            // HP filter
            l = biquadProcessSample(l, coeffs: hpCoeffs, state: &hpStateL)
            r = biquadProcessSample(r, coeffs: hpCoeffs, state: &hpStateR)

            // LP filter
            l = biquadProcessSample(l, coeffs: lpCoeffs, state: &lpStateL)
            r = biquadProcessSample(r, coeffs: lpCoeffs, state: &lpStateR)

            // Pan (equal-power)
            l *= panL
            r *= panR

            left[i] += l
            right[i] += r
            peak = max(peak, abs(l), abs(r))
        }

        position += toWrite
        return (position >= sample.frameCount, peak)
    }
}

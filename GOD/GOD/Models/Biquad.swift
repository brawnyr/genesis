import Foundation

// MARK: - BiquadState

struct BiquadState {
    var z1: Float = 0
    var z2: Float = 0
}

// MARK: - BiquadCoefficients

struct BiquadCoefficients {
    var b0: Float
    var b1: Float
    var b2: Float
    var a1: Float
    var a2: Float

    /// Bypass — passes signal unchanged.
    static let bypass = BiquadCoefficients(b0: 1, b1: 0, b2: 0, a1: 0, a2: 0)

    /// Standard 12dB/oct Butterworth low-pass filter.
    static func lowPass(cutoff: Float, sampleRate: Float) -> BiquadCoefficients {
        let w0 = 2.0 * Float.pi * cutoff / sampleRate
        let cosW0 = cos(w0)
        let sinW0 = sin(w0)
        let alpha = sinW0 / (2.0 * sqrt(2.0)) // Q = 1/sqrt(2) for Butterworth

        let b0 = (1.0 - cosW0) / 2.0
        let b1 = 1.0 - cosW0
        let b2 = (1.0 - cosW0) / 2.0
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cosW0
        let a2 = 1.0 - alpha

        return BiquadCoefficients(
            b0: b0 / a0,
            b1: b1 / a0,
            b2: b2 / a0,
            a1: a1 / a0,
            a2: a2 / a0
        )
    }

    /// Standard 12dB/oct Butterworth high-pass filter.
    static func highPass(cutoff: Float, sampleRate: Float) -> BiquadCoefficients {
        let w0 = 2.0 * Float.pi * cutoff / sampleRate
        let cosW0 = cos(w0)
        let sinW0 = sin(w0)
        let alpha = sinW0 / (2.0 * sqrt(2.0)) // Q = 1/sqrt(2) for Butterworth

        let b0 = (1.0 + cosW0) / 2.0
        let b1 = -(1.0 + cosW0)
        let b2 = (1.0 + cosW0) / 2.0
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cosW0
        let a2 = 1.0 - alpha

        return BiquadCoefficients(
            b0: b0 / a0,
            b1: b1 / a0,
            b2: b2 / a0,
            a1: a1 / a0,
            a2: a2 / a0
        )
    }
}

// MARK: - Processing

/// Processes a single sample through a biquad filter using Direct Form II Transposed.
func biquadProcessSample(_ input: Float, coeffs: BiquadCoefficients, state: inout BiquadState) -> Float {
    let output = coeffs.b0 * input + state.z1
    state.z1 = coeffs.b1 * input - coeffs.a1 * output + state.z2
    state.z2 = coeffs.b2 * input - coeffs.a2 * output
    return output
}

/// Maps MIDI CC value (0–127) to frequency (20Hz–20kHz) exponentially.
/// Formula: 20 * pow(1000, cc/127)
func ccToFrequency(_ cc: Int) -> Float {
    let normalized = Float(cc) / 127.0
    return 20.0 * pow(1000.0, normalized)
}

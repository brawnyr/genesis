import Foundation

/// Brickwall peak limiter for the master bus.
/// Instant attack, smooth release. Transparent until signal exceeds ceiling.
struct PeakLimiter {
    /// Ceiling in linear amplitude. Default -1 dBTP ≈ 0.891
    let ceiling: Float

    /// Release coefficient per sample (derived from release time)
    private let releaseCoeff: Float

    /// Current gain envelope (1.0 = no reduction)
    private var envelope: Float = 1.0

    init(ceiling: Float = 0.891, releaseMsec: Float = 100, sampleRate: Float = 44100) {
        self.ceiling = ceiling
        // Exponential release: coeff = exp(-1 / (releaseTime * sampleRate))
        let releaseSamples = releaseMsec * 0.001 * sampleRate
        self.releaseCoeff = expf(-1.0 / releaseSamples)
    }

    /// Process stereo buffers in-place. Returns peak level after limiting.
    mutating func process(left: inout [Float], right: inout [Float], count: Int) -> Float {
        var peak: Float = 0
        for i in 0..<count {
            let samplePeak = max(abs(left[i]), abs(right[i]))

            // Target gain: how much we need to reduce to stay under ceiling
            let targetGain: Float = samplePeak > ceiling ? ceiling / samplePeak : 1.0

            if targetGain < envelope {
                // Instant attack — snap to target
                envelope = targetGain
            } else {
                // Smooth release back toward 1.0
                envelope = releaseCoeff * envelope + (1.0 - releaseCoeff) * targetGain
            }

            left[i] *= envelope
            right[i] *= envelope
            peak = max(peak, abs(left[i]), abs(right[i]))
        }
        return peak
    }
}

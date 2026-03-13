import Foundation

struct Voice {
    var active: Bool = false
    var padIndex: Int = -1
    var blockOffset: Int = 0

    private var sample: Sample?
    private(set) var velocity: Float = 0
    private var position: Int = 0

    // Per-voice filter state (separate L/R for stereo independence)
    var hpStateL = BiquadState()
    var hpStateR = BiquadState()
    var lpStateL = BiquadState()
    var lpStateR = BiquadState()

    // Pan smoothing state
    var prevPanL: Float = cos(0.5 * .pi / 2.0)
    var prevPanR: Float = sin(0.5 * .pi / 2.0)

    mutating func start(sample: Sample, velocity: Float, padIndex: Int) {
        self.sample = sample
        self.velocity = velocity
        self.padIndex = padIndex
        self.position = 0
        self.blockOffset = 0
        self.active = true
        self.hpStateL = BiquadState()
        self.hpStateR = BiquadState()
        self.lpStateL = BiquadState()
        self.lpStateR = BiquadState()
        self.prevPanL = cos(0.5 * .pi / 2.0)
        self.prevPanR = sin(0.5 * .pi / 2.0)
    }

    /// Mixes this voice into stereo buffers with filtering and panning.
    /// Returns (finished, peak).
    mutating func fill(intoLeft left: inout [Float], right: inout [Float], count: Int,
                       pan: Float, volume: Float, hpCoeffs: BiquadCoefficients, lpCoeffs: BiquadCoefficients
    ) -> (finished: Bool, peak: Float) {
        guard let sample, active else { return (true, 0) }

        let startIdx = blockOffset
        blockOffset = 0

        let remaining = sample.frameCount - position
        let available = count - startIdx
        let toWrite = min(available, remaining)
        guard toWrite > 0 else {
            active = false
            return (true, 0)
        }

        var peak: Float = 0
        let gain = velocity * volume

        let targetPanL = cos(pan * .pi / 2.0)
        let targetPanR = sin(pan * .pi / 2.0)

        for i in 0..<toWrite {
            // Smooth pan to avoid zipper noise
            prevPanL += (targetPanL - prevPanL) * 0.01
            prevPanR += (targetPanR - prevPanR) * 0.01

            var l = sample.left[position + i] * gain
            var r = sample.right[position + i] * gain

            // HP filter
            l = biquadProcessSample(l, coeffs: hpCoeffs, state: &hpStateL)
            r = biquadProcessSample(r, coeffs: hpCoeffs, state: &hpStateR)

            // LP filter
            l = biquadProcessSample(l, coeffs: lpCoeffs, state: &lpStateL)
            r = biquadProcessSample(r, coeffs: lpCoeffs, state: &lpStateR)

            // Pan (equal-power, smoothed)
            l *= prevPanL
            r *= prevPanR

            let idx = startIdx + i
            left[idx] += l
            right[idx] += r
            peak = max(peak, abs(l), abs(r))
        }

        position += toWrite
        if position >= sample.frameCount {
            active = false
            return (true, peak)
        }
        return (false, peak)
    }
}

struct VoicePool {
    static let capacity = 32

    var slots: [Voice] = Array(repeating: Voice(), count: VoicePool.capacity)

    /// Allocate a voice slot, returning the index if successful.
    mutating func allocate(sample: Sample, velocity: Float, padIndex: Int) -> Int? {
        for i in 0..<Self.capacity {
            if !slots[i].active {
                slots[i].start(sample: sample, velocity: velocity, padIndex: padIndex)
                return i
            }
        }
        return nil
    }

    /// Kill all voices.
    mutating func killAll() {
        for i in 0..<Self.capacity {
            slots[i].active = false
        }
    }

    /// Kill all voices for a specific pad.
    mutating func killPad(_ padIndex: Int) {
        for i in 0..<Self.capacity {
            if slots[i].active && slots[i].padIndex == padIndex {
                slots[i].active = false
            }
        }
    }

    /// Kill all pad voices (padIndex >= 0), leaving metronome clicks (padIndex == -1) alive.
    mutating func killPads() {
        for i in 0..<Self.capacity {
            if slots[i].active && slots[i].padIndex >= 0 {
                slots[i].active = false
            }
        }
    }

    /// Check if a specific pad has any active voice.
    func hasPadVoice(_ padIndex: Int) -> Bool {
        for i in 0..<Self.capacity {
            if slots[i].active && slots[i].padIndex == padIndex {
                return true
            }
        }
        return false
    }

    /// Set of pad indices that currently have active voices.
    var activePadIndices: Set<Int> {
        var result = Set<Int>()
        for i in 0..<Self.capacity {
            if slots[i].active && slots[i].padIndex >= 0 {
                result.insert(slots[i].padIndex)
            }
        }
        return result
    }
}

import Foundation

struct Voice {
    var active: Bool = false
    var padIndex: Int = -1
    var blockOffset: Int = 0

    private var sample: Sample?
    private(set) var velocity: Float = 0
    private var position: Int = 0

    // Declick: fade out over ~1ms (44 samples at 44.1kHz) when killed
    private static let declickFrames = 44
    private var fadeOut: Bool = false
    private var fadeRemaining: Int = 0

    // Per-voice filter state (separate L/R for stereo independence)
    var hpStateL = BiquadState()
    var hpStateR = BiquadState()
    var lpStateL = BiquadState()
    var lpStateR = BiquadState()

    // Pan smoothing state
    var prevPanL: Float = cos(0.5 * .pi / 2.0)
    var prevPanR: Float = sin(0.5 * .pi / 2.0)

    mutating func start(sample: Sample, velocity: Float, padIndex: Int, pan: Float = 0.5) {
        self.sample = sample
        self.velocity = velocity
        self.padIndex = padIndex
        self.position = 0
        self.blockOffset = 0
        self.active = true
        self.fadeOut = false
        self.fadeRemaining = 0
        self.hpStateL = BiquadState()
        self.hpStateR = BiquadState()
        self.lpStateL = BiquadState()
        self.lpStateR = BiquadState()
        self.prevPanL = cos(pan * .pi / 2.0)
        self.prevPanR = sin(pan * .pi / 2.0)
    }

    /// Begin a short fadeout instead of instant kill. Voice deactivates when fade completes.
    mutating func kill() {
        guard active, !fadeOut else { return }
        fadeOut = true
        fadeRemaining = Self.declickFrames
    }

    /// Hard kill — no fade. Use only when silence is already guaranteed (e.g. transport stop).
    mutating func killHard() {
        active = false
        fadeOut = false
        fadeRemaining = 0
    }

    /// Mixes this voice into stereo buffers with filtering and panning.
    /// Returns (finished, peak).
    /// Uses unsafe pointer access to eliminate bounds checks in the inner loop.
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
            fadeOut = false
            return (true, 0)
        }

        var peak: Float = 0
        let gain = velocity * volume

        let targetPanL = cos(pan * .pi / 2.0)
        let targetPanR = sin(pan * .pi / 2.0)

        let pos = position
        let isFading = fadeOut
        var fadeRem = fadeRemaining
        let fadeTotal = Float(Self.declickFrames)

        sample.left.withUnsafeBufferPointer { sL in
            sample.right.withUnsafeBufferPointer { sR in
                left.withUnsafeMutableBufferPointer { outL in
                    right.withUnsafeMutableBufferPointer { outR in
                        for i in 0..<toWrite {
                            // Smooth pan to avoid zipper noise
                            prevPanL += (targetPanL - prevPanL) * 0.01
                            prevPanR += (targetPanR - prevPanR) * 0.01

                            var l = sL[pos + i] * gain
                            var r = sR[pos + i] * gain

                            // HP filter
                            l = biquadProcessSample(l, coeffs: hpCoeffs, state: &hpStateL)
                            r = biquadProcessSample(r, coeffs: hpCoeffs, state: &hpStateR)

                            // LP filter
                            l = biquadProcessSample(l, coeffs: lpCoeffs, state: &lpStateL)
                            r = biquadProcessSample(r, coeffs: lpCoeffs, state: &lpStateR)

                            // Declick fade
                            if isFading && fadeRem > 0 {
                                let fadeGain = Float(fadeRem) / fadeTotal
                                l *= fadeGain
                                r *= fadeGain
                                fadeRem -= 1
                            } else if isFading {
                                // Fade complete — stop writing
                                break
                            }

                            // Pan (equal-power, smoothed)
                            l *= prevPanL
                            r *= prevPanR

                            let idx = startIdx + i
                            outL[idx] += l
                            outR[idx] += r
                            peak = max(peak, abs(l), abs(r))
                        }
                    }
                }
            }
        }

        if isFading {
            fadeRemaining = fadeRem
            if fadeRem <= 0 {
                active = false
                fadeOut = false
                return (true, peak)
            }
        }

        position += toWrite
        if position >= sample.frameCount {
            active = false
            fadeOut = false
            return (true, peak)
        }
        return (false, peak)
    }
}

struct VoicePool {
    static let capacity = 32

    var slots: [Voice] = Array(repeating: Voice(), count: VoicePool.capacity)

    /// Allocate a voice slot, returning the index if successful.
    mutating func allocate(sample: Sample, velocity: Float, padIndex: Int, pan: Float = 0.5) -> Int? {
        for i in 0..<Self.capacity {
            if !slots[i].active {
                slots[i].start(sample: sample, velocity: velocity, padIndex: padIndex, pan: pan)
                return i
            }
        }
        return nil
    }

    /// Kill all voices (hard — for transport stop where silence is expected).
    mutating func killAll() {
        for i in 0..<Self.capacity {
            slots[i].killHard()
        }
    }

    /// Kill all voices for a specific pad (with declick fade).
    mutating func killPad(_ padIndex: Int) {
        for i in 0..<Self.capacity {
            if slots[i].active && slots[i].padIndex == padIndex {
                slots[i].kill()
            }
        }
    }

    /// Kill all pad voices with declick (padIndex >= 0), leaving metronome clicks (padIndex == -1) alive.
    mutating func killPads() {
        for i in 0..<Self.capacity {
            if slots[i].active && slots[i].padIndex >= 0 {
                slots[i].kill()
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

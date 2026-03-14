// Genesis/Genesis/Engine/ReverbProcessor.swift
// Schroeder stereo reverb — 4 parallel comb filters + 2 series allpass filters
import Foundation

final class ReverbProcessor {
    // Comb filter delay lengths (samples at 44100Hz) — classic Schroeder primes
    private static let combDelays = [1557, 1617, 1491, 1422]
    // Stereo spread: slightly offset R channel
    private static let combDelaysR = [1577, 1637, 1511, 1442]
    // Allpass delay lengths
    private static let allpassDelays = [225, 556]
    private static let allpassDelaysR = [241, 572]

    // Comb feedback (controls decay time)
    private let combFeedback: Float = 0.84

    // Allpass coefficient
    private let allpassGain: Float = 0.5

    // Delay line buffers — L
    private var combBuffersL: [[Float]]
    private var combIndexL: [Int]
    private var allpassBuffersL: [[Float]]
    private var allpassIndexL: [Int]

    // Delay line buffers — R
    private var combBuffersR: [[Float]]
    private var combIndexR: [Int]
    private var allpassBuffersR: [[Float]]
    private var allpassIndexR: [Int]

    init() {
        combBuffersL = Self.combDelays.map { [Float](repeating: 0, count: $0) }
        combIndexL = [Int](repeating: 0, count: Self.combDelays.count)
        allpassBuffersL = Self.allpassDelays.map { [Float](repeating: 0, count: $0) }
        allpassIndexL = [Int](repeating: 0, count: Self.allpassDelays.count)

        combBuffersR = Self.combDelaysR.map { [Float](repeating: 0, count: $0) }
        combIndexR = [Int](repeating: 0, count: Self.combDelaysR.count)
        allpassBuffersR = Self.allpassDelaysR.map { [Float](repeating: 0, count: $0) }
        allpassIndexR = [Int](repeating: 0, count: Self.allpassDelaysR.count)
    }

    /// Process stereo reverb in-place on send buffers, then add wet signal to output.
    /// sendL/sendR contain the reverb send signal. outputL/outputR are the main mix to add into.
    func process(
        sendL: UnsafePointer<Float>,
        sendR: UnsafePointer<Float>,
        intoLeft outputL: inout [Float],
        intoRight outputR: inout [Float],
        count: Int
    ) {
        for i in 0..<count {
            let inL = sendL[i]
            let inR = sendR[i]

            // Parallel comb filters — L
            var combOutL: Float = 0
            for c in 0..<Self.combDelays.count {
                let idx = combIndexL[c]
                let delayed = combBuffersL[c][idx]
                combBuffersL[c][idx] = inL + delayed * combFeedback
                combIndexL[c] = (idx + 1) % Self.combDelays[c]
                combOutL += delayed
            }
            combOutL *= 0.25

            // Parallel comb filters — R
            var combOutR: Float = 0
            for c in 0..<Self.combDelaysR.count {
                let idx = combIndexR[c]
                let delayed = combBuffersR[c][idx]
                combBuffersR[c][idx] = inR + delayed * combFeedback
                combIndexR[c] = (idx + 1) % Self.combDelaysR[c]
                combOutR += delayed
            }
            combOutR *= 0.25

            // Series allpass filters — L
            var apL = combOutL
            for a in 0..<Self.allpassDelays.count {
                let idx = allpassIndexL[a]
                let delayed = allpassBuffersL[a][idx]
                let input = apL + delayed * allpassGain
                allpassBuffersL[a][idx] = input
                apL = delayed - input * allpassGain
                allpassIndexL[a] = (idx + 1) % Self.allpassDelays[a]
            }

            // Series allpass filters — R
            var apR = combOutR
            for a in 0..<Self.allpassDelaysR.count {
                let idx = allpassIndexR[a]
                let delayed = allpassBuffersR[a][idx]
                let input = apR + delayed * allpassGain
                allpassBuffersR[a][idx] = input
                apR = delayed - input * allpassGain
                allpassIndexR[a] = (idx + 1) % Self.allpassDelaysR[a]
            }

            outputL[i] += apL
            outputR[i] += apR
        }
    }

    func reset() {
        for c in 0..<combBuffersL.count {
            combBuffersL[c] = [Float](repeating: 0, count: combBuffersL[c].count)
            combIndexL[c] = 0
        }
        for c in 0..<combBuffersR.count {
            combBuffersR[c] = [Float](repeating: 0, count: combBuffersR[c].count)
            combIndexR[c] = 0
        }
        for a in 0..<allpassBuffersL.count {
            allpassBuffersL[a] = [Float](repeating: 0, count: allpassBuffersL[a].count)
            allpassIndexL[a] = 0
        }
        for a in 0..<allpassBuffersR.count {
            allpassBuffersR[a] = [Float](repeating: 0, count: allpassBuffersR[a].count)
            allpassIndexR[a] = 0
        }
    }
}

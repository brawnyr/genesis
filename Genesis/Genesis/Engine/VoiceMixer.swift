// Genesis/Genesis/Engine/VoiceMixer.swift
import Foundation

enum VoiceMixer {
    /// Mix all active voices into stereo output buffers + reverb send buffers.
    /// Returns per-pad peak levels.
    /// Uses pre-allocated scratch buffers to avoid heap allocations on the audio thread.
    static func mix(
        pool: inout VoicePool,
        layers: [Layer],
        cachedHP: [BiquadCoefficients],
        cachedLP: [BiquadCoefficients],
        intoLeft bufferL: inout [Float],
        intoRight bufferR: inout [Float],
        reverbSendL: inout [Float],
        reverbSendR: inout [Float],
        scratchL: inout [Float],
        scratchR: inout [Float],
        count: Int
    ) -> [Float] {
        var levels = [Float](repeating: 0, count: PadBank.padCount)
        for i in 0..<VoicePool.capacity {
            guard pool.slots[i].active else { continue }
            let padIdx = pool.slots[i].padIndex
            let validPad = padIdx >= 0 && padIdx < PadBank.padCount
            let hpCoeffs = validPad ? cachedHP[padIdx] : .bypass
            let lpCoeffs = validPad ? cachedLP[padIdx] : .bypass
            let pan = validPad ? layers[padIdx].pan : 0.5
            let volume = validPad ? layers[padIdx].volume : 1.0
            let reverbAmt = validPad ? layers[padIdx].reverbSend : 0.0

            let needsReverb = reverbAmt > 0.001

            if needsReverb {
                // Render voice into scratch buffers (zeroed first), then add to both main and reverb
                let startIdx = pool.slots[i].blockOffset
                for j in startIdx..<count {
                    scratchL[j] = 0
                    scratchR[j] = 0
                }

                let (_, peak) = pool.slots[i].fill(intoLeft: &scratchL, right: &scratchR, count: count,
                                                     pan: pan, volume: volume, hpCoeffs: hpCoeffs, lpCoeffs: lpCoeffs)

                // Sum scratch into main output and reverb send
                for j in startIdx..<count {
                    bufferL[j] += scratchL[j]
                    bufferR[j] += scratchR[j]
                    reverbSendL[j] += scratchL[j] * reverbAmt
                    reverbSendR[j] += scratchR[j] * reverbAmt
                }

                if validPad {
                    levels[padIdx] = max(levels[padIdx], peak)
                }
            } else {
                let (_, peak) = pool.slots[i].fill(intoLeft: &bufferL, right: &bufferR, count: count,
                                                     pan: pan, volume: volume, hpCoeffs: hpCoeffs, lpCoeffs: lpCoeffs)
                if validPad {
                    levels[padIdx] = max(levels[padIdx], peak)
                }
            }
        }
        return levels
    }
}

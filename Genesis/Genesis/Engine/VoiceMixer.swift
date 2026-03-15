// Genesis/Genesis/Engine/VoiceMixer.swift
import Foundation

enum VoiceMixer {
    /// Mix all active voices into stereo output buffers + reverb send buffers.
    /// Returns per-pad peak levels.
    /// Layer params (volumes, pans, reverbSends) are passed as pre-snapshotted arrays
    /// to avoid reading shared state outside the audio lock.
    static func mix(
        pool: inout VoicePool,
        layerVolumes: [Float],
        layerPans: [Float],
        layerReverbSends: [Float],
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
            let pan = validPad ? layerPans[padIdx] : 0.5
            let volume = validPad ? layerVolumes[padIdx] : 1.0
            let reverbAmt = validPad ? layerReverbSends[padIdx] : 0.0

            let needsReverb = reverbAmt > 0.001

            if needsReverb {
                // Render voice into scratch buffers (zeroed first), then add to both main and reverb.
                // Zero the FULL range — not just [startIdx..<count] — to prevent stale data
                // in [0..<startIdx) from bleeding into output and reverb sends.
                for j in 0..<count {
                    scratchL[j] = 0
                    scratchR[j] = 0
                }

                let (_, peak) = pool.slots[i].fill(intoLeft: &scratchL, right: &scratchR, count: count,
                                                     pan: pan, volume: volume, hpCoeffs: hpCoeffs, lpCoeffs: lpCoeffs)

                // Sum scratch into main output and reverb send
                for j in 0..<count {
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

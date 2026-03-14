// Genesis/Genesis/Engine/VoiceMixer.swift
import Foundation

enum VoiceMixer {
    /// Mix all active voices into stereo output buffers + reverb send buffers.
    /// Returns per-pad peak levels.
    static func mix(
        pool: inout VoicePool,
        layers: [Layer],
        cachedHP: [BiquadCoefficients],
        cachedLP: [BiquadCoefficients],
        intoLeft bufferL: inout [Float],
        intoRight bufferR: inout [Float],
        reverbSendL: inout [Float],
        reverbSendR: inout [Float],
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

            // Snapshot buffer state before fill so we can extract this voice's contribution
            let needsReverb = reverbAmt > 0.001

            if needsReverb {
                // Record start positions for reverb extraction
                let startIdx = pool.slots[i].blockOffset
                let snapshotL = Array(bufferL[startIdx..<count])
                let snapshotR = Array(bufferR[startIdx..<count])

                let (_, peak) = pool.slots[i].fill(intoLeft: &bufferL, right: &bufferR, count: count,
                                                     pan: pan, volume: volume, hpCoeffs: hpCoeffs, lpCoeffs: lpCoeffs)

                // Extract this voice's contribution and add to reverb send
                for j in startIdx..<count {
                    let voiceL = bufferL[j] - snapshotL[j - startIdx]
                    let voiceR = bufferR[j] - snapshotR[j - startIdx]
                    reverbSendL[j] += voiceL * reverbAmt
                    reverbSendR[j] += voiceR * reverbAmt
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

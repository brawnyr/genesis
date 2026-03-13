// Genesis/Genesis/Engine/VoiceMixer.swift
import Foundation

enum VoiceMixer {
    /// Mix all active voices into stereo output buffers.
    /// Returns per-pad peak levels.
    static func mix(
        pool: inout VoicePool,
        layers: [Layer],
        cachedHP: [BiquadCoefficients],
        cachedLP: [BiquadCoefficients],
        intoLeft bufferL: inout [Float],
        intoRight bufferR: inout [Float],
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
            let (_, peak) = pool.slots[i].fill(intoLeft: &bufferL, right: &bufferR, count: count,
                                                 pan: pan, volume: volume, hpCoeffs: hpCoeffs, lpCoeffs: lpCoeffs)
            if validPad {
                levels[padIdx] = max(levels[padIdx], peak)
            }
        }
        return levels
    }
}

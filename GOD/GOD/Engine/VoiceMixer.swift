// GOD/GOD/Engine/VoiceMixer.swift
import Foundation

enum VoiceMixer {
    /// Mix all active voices into stereo output buffers.
    /// Returns per-pad peak levels. Removes finished voices from the array.
    static func mix(
        voices: inout [Voice],
        layers: [Layer],
        cachedHP: [BiquadCoefficients],
        cachedLP: [BiquadCoefficients],
        intoLeft bufferL: inout [Float],
        intoRight bufferR: inout [Float],
        count: Int
    ) -> [Float] {
        var levels = [Float](repeating: 0, count: PadBank.padCount)
        voices = voices.compactMap { voice in
            var v = voice
            let padIdx = v.padIndex
            let validPad = padIdx >= 0 && padIdx < PadBank.padCount
            let hpCoeffs = validPad ? cachedHP[padIdx] : .bypass
            let lpCoeffs = validPad ? cachedLP[padIdx] : .bypass
            let pan = validPad ? layers[padIdx].pan : 0.5
            let volume = validPad ? layers[padIdx].volume : 1.0
            let (done, peak) = v.fill(intoLeft: &bufferL, right: &bufferR, count: count,
                                       pan: pan, volume: volume, hpCoeffs: hpCoeffs, lpCoeffs: lpCoeffs)
            if validPad {
                levels[padIdx] = max(levels[padIdx], peak)
            }
            return done ? nil : v
        }
        return levels
    }
}

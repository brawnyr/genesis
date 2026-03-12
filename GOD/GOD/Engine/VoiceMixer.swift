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
            let hpCoeffs = padIdx >= 0 && padIdx < PadBank.padCount ? cachedHP[padIdx] : .bypass
            let lpCoeffs = padIdx >= 0 && padIdx < PadBank.padCount ? cachedLP[padIdx] : .bypass
            let pan = padIdx >= 0 && padIdx < PadBank.padCount ? layers[padIdx].pan : 0.5
            let volume = padIdx >= 0 && padIdx < PadBank.padCount ? layers[padIdx].volume : 1.0
            let (done, peak) = v.fill(intoLeft: &bufferL, right: &bufferR, count: count,
                                       pan: pan, volume: volume, hpCoeffs: hpCoeffs, lpCoeffs: lpCoeffs)
            if padIdx >= 0 && padIdx < PadBank.padCount {
                levels[padIdx] = max(levels[padIdx], peak)
            }
            return done ? nil : v
        }
        return levels
    }
}

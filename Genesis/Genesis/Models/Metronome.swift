import Foundation

struct Metronome {
    private static let clickDuration: Double = 0.03
    private static let clickDecayRate: Double = 80.0
    private static let attackDuration: Double = 0.002  // 2ms fade-in — prevents onset click

    // Four distinct beats — warm, analog-style (tamed amplitudes)
    private static let beatParams: [(freq: Double, amp: Float)] = [
        (880.0, 0.45),   // beat 1 — downbeat, the ONE
        (660.0, 0.25),   // beat 2 — soft
        (720.0, 0.30),   // beat 3 — medium
        (620.0, 0.20),   // beat 4 — softest
    ]

    var isOn: Bool = true
    var volume: Float = 0.25

    // Cached click samples per beat position
    private static let cachedBeats: [Sample] = beatParams.map { p in
        generateClick(freq: p.freq, amp: p.amp)
    }

    func beatLengthFrames(bpm: Int, sampleRate: Double) -> Int {
        Self.beatLengthFramesStatic(bpm: bpm, sampleRate: sampleRate)
    }

    static func beatLengthFramesStatic(bpm: Int, sampleRate: Double) -> Int {
        Int(60.0 / Double(bpm) * sampleRate)
    }

    /// Get click sample for beat position (0-3). Wraps for odd time signatures.
    static func click(beatIndex: Int) -> Sample {
        cachedBeats[beatIndex % cachedBeats.count]
    }

    private static func generateClick(freq: Double, amp: Float) -> Sample {
        let sampleRate = Transport.sampleRate
        let frameCount = Int(clickDuration * sampleRate)
        let attackFrames = Int(attackDuration * sampleRate)

        var buffer = [Float](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let attack = Float(min(Double(i) / Double(max(attackFrames, 1)), 1.0))
            let decay = Float(exp(-t * clickDecayRate))
            let fundamental = Float(sin(2.0 * .pi * freq * t))
            let harmonic = Float(sin(2.0 * .pi * (freq * 2.0) * t))
            let mix = (fundamental + 0.5 * harmonic) / 1.5
            buffer[i] = mix * attack * decay * amp
        }
        return Sample(name: "click", left: buffer, right: buffer, sampleRate: sampleRate)
    }
}

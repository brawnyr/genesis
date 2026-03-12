import Foundation

struct Metronome {
    private static let clickDuration: Double = 0.02
    private static let downbeatFreq: Double = 1500.0
    private static let beatFreq: Double = 1000.0
    private static let downbeatAmplitude: Float = 0.8
    private static let beatAmplitude: Float = 0.4
    private static let clickDecayRate: Double = 150.0

    var isOn: Bool = true
    var volume: Float = 0.5

    // Cached click samples — generated once, reused on every beat
    private static let cachedDownbeat: Sample = generateClickInternal(isDownbeat: true)
    private static let cachedBeat: Sample = generateClickInternal(isDownbeat: false)

    func beatLengthFrames(bpm: Int, sampleRate: Double) -> Int {
        Self.beatLengthFramesStatic(bpm: bpm, sampleRate: sampleRate)
    }

    static func beatLengthFramesStatic(bpm: Int, sampleRate: Double) -> Int {
        Int(60.0 / Double(bpm) * sampleRate)
    }

    static func click(isDownbeat: Bool) -> Sample {
        isDownbeat ? cachedDownbeat : cachedBeat
    }

    private static func generateClickInternal(isDownbeat: Bool) -> Sample {
        let sampleRate = Transport.sampleRate
        let frameCount = Int(clickDuration * sampleRate)
        let frequency: Double = isDownbeat ? downbeatFreq : beatFreq
        let amplitude: Float = isDownbeat ? downbeatAmplitude : beatAmplitude

        var buffer = [Float](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let envelope = Float(exp(-t * clickDecayRate))
            let sine = Float(sin(2.0 * .pi * frequency * t))
            buffer[i] = sine * envelope * amplitude
        }
        return Sample(name: "click", left: buffer, right: buffer, sampleRate: sampleRate)
    }
}

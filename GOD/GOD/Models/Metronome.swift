import Foundation

struct Metronome {
    var isOn: Bool = true
    var volume: Float = 0.5

    func beatLengthFrames(bpm: Int, sampleRate: Double) -> Int {
        Self.beatLengthFramesStatic(bpm: bpm, sampleRate: sampleRate)
    }

    static func beatLengthFramesStatic(bpm: Int, sampleRate: Double) -> Int {
        Int(60.0 / Double(bpm) * sampleRate)
    }

    static func generateClick(isDownbeat: Bool, sampleRate: Double) -> Sample {
        let duration = 0.02 // 20ms
        let frameCount = Int(duration * sampleRate)
        let frequency: Double = isDownbeat ? 1500.0 : 1000.0
        let amplitude: Float = isDownbeat ? 0.8 : 0.4

        var buffer = [Float](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let envelope = Float(exp(-t * 150.0))
            let sine = Float(sin(2.0 * .pi * frequency * t))
            buffer[i] = sine * envelope * amplitude
        }
        return Sample(name: "click", left: buffer, right: buffer, sampleRate: sampleRate)
    }
}

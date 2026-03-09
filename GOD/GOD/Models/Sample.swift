import Foundation
import AVFoundation

struct Sample {
    let name: String
    let data: [Float]
    let sampleRate: Double

    static func load(from url: URL) throws -> Sample {
        let file = try AVAudioFile(forReading: url)
        let format = AVAudioFormat(standardFormatWithSampleRate: file.fileFormat.sampleRate, channels: 1)!
        let frameCount = AVAudioFrameCount(file.length)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        try file.read(into: buffer)

        let floatData = Array(UnsafeBufferPointer(
            start: buffer.floatChannelData![0],
            count: Int(buffer.frameLength)
        ))

        let name = url.deletingPathExtension().lastPathComponent
        return Sample(name: name, data: floatData, sampleRate: file.fileFormat.sampleRate)
    }
}

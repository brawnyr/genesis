import Foundation
import AVFoundation

enum SampleError: Error {
    case conversionFailed
}

struct Sample {
    let name: String
    let left: [Float]
    let right: [Float]
    let sampleRate: Double

    var frameCount: Int { left.count }

    var durationMs: Double {
        Double(frameCount) / sampleRate * 1000.0
    }

    static func load(from url: URL) throws -> Sample {
        let file = try AVAudioFile(forReading: url)
        let sourceFormat = file.processingFormat
        guard let targetFormat = AVAudioFormat(standardFormatWithSampleRate: Transport.sampleRate, channels: 2) else {
            throw SampleError.conversionFailed
        }

        let sourceFrameCount = AVAudioFrameCount(file.length)
        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: sourceFrameCount) else {
            throw SampleError.conversionFailed
        }
        try file.read(into: sourceBuffer)

        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw SampleError.conversionFailed
        }

        let ratio = Transport.sampleRate / sourceFormat.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(sourceFrameCount) * ratio) + 100
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputCapacity) else {
            throw SampleError.conversionFailed
        }

        var error: NSError?
        var consumed = false
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .endOfStream
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        if let error = error { throw error }

        let frameLen = Int(outputBuffer.frameLength)
        let leftData = Array(UnsafeBufferPointer(
            start: outputBuffer.floatChannelData![0], count: frameLen
        ))
        let rightData: [Float]
        if outputBuffer.format.channelCount >= 2 {
            rightData = Array(UnsafeBufferPointer(
                start: outputBuffer.floatChannelData![1], count: frameLen
            ))
        } else {
            rightData = leftData
        }

        let name = url.deletingPathExtension().lastPathComponent
        return Sample(name: name, left: leftData, right: rightData, sampleRate: Transport.sampleRate)
    }
}

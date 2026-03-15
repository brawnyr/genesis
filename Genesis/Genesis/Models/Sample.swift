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
    var peakDb: Float = 0  // cached at load time

    var frameCount: Int { left.count }

    var durationMs: Double {
        Double(frameCount) / sampleRate * 1000.0
    }

    /// Compute peak dBFS from sample data.
    static func computePeakDb(left: [Float], right: [Float]) -> Float {
        var peak: Float = 0
        let count = min(left.count, right.count)
        for i in 0..<count {
            peak = max(peak, abs(left[i]), abs(right[i]))
        }
        return peak > 0 ? 20 * log10(peak) : -100
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
        let outputCapacity = AVAudioFrameCount(ceil(Double(sourceFrameCount) * ratio)) + 1
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
        guard let channelData = outputBuffer.floatChannelData else {
            throw SampleError.conversionFailed
        }
        let leftData = Array(UnsafeBufferPointer(
            start: channelData[0], count: frameLen
        ))
        let rightData: [Float]
        if outputBuffer.format.channelCount >= 2 {
            rightData = Array(UnsafeBufferPointer(
                start: channelData[1], count: frameLen
            ))
        } else {
            // Mono source — shares backing store via COW (safe since Sample is immutable after load)
            rightData = leftData
        }

        let name = url.deletingPathExtension().lastPathComponent
        let peak = computePeakDb(left: leftData, right: rightData)
        return Sample(name: name, left: leftData, right: rightData, sampleRate: Transport.sampleRate, peakDb: peak)
    }
}

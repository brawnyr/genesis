import Foundation
import AVFoundation
import os

private let logger = Logger(subsystem: "genesis", category: "GenesisCapture")

struct GenesisCapture {
    enum State {
        case off, on
    }

    var state: State = .off

    // Single contiguous pre-allocated buffer per channel.
    // Allocated once at startCapture() on the main thread, then zero audio-thread allocations.
    // Sized for up to 2 minutes of capture. If exceeded, capture stops cleanly.
    private static let maxCaptureSeconds = 120
    private static let sampleRate = 44100
    private static let maxFrames = maxCaptureSeconds * sampleRate
    private static let chunkFrames = sampleRate * 10  // 10s chunks for WAV writing

    private var bufferL: [Float] = []
    private var bufferR: [Float] = []
    private var writePos: Int = 0

    var accumulatedFrames: Int { writePos }

    mutating func startCapture() {
        state = .on
        // Reuse existing allocation if large enough; otherwise allocate once (main thread)
        if bufferL.count < Self.maxFrames {
            bufferL = [Float](repeating: 0, count: Self.maxFrames)
            bufferR = [Float](repeating: 0, count: Self.maxFrames)
        }
        writePos = 0
    }

    /// Stop capture and return accumulated audio as chunks for WAV writing.
    /// Call from the main thread — chunk slicing allocates here, not on the audio thread.
    mutating func stopCapture() -> [([Float], [Float])] {
        state = .off
        guard writePos > 0 else { return [] }
        // Split into ~10s chunks for streamed WAV writing
        var chunks: [([Float], [Float])] = []
        chunks.reserveCapacity((writePos / Self.chunkFrames) + 1)
        var offset = 0
        while offset < writePos {
            let end = min(offset + Self.chunkFrames, writePos)
            chunks.append((Array(bufferL[offset..<end]), Array(bufferR[offset..<end])))
            offset = end
        }
        writePos = 0
        return chunks
    }

    /// Append audio from the render callback into the pre-allocated buffer.
    /// Zero heap allocations — just memcpy into the contiguous buffer.
    mutating func appendFromBuffers(left: UnsafeBufferPointer<Float>, right: UnsafeBufferPointer<Float>) {
        guard state == .on, !bufferL.isEmpty else { return }
        let count = left.count
        let space = bufferL.count - writePos
        let toCopy = min(count, space)
        guard toCopy > 0 else { return }
        for i in 0..<toCopy {
            bufferL[writePos + i] = left[i]
            bufferR[writePos + i] = right[i]
        }
        writePos += toCopy
    }

    /// Write chunks to a WAV file on a background queue.
    static func writeChunksToFile(_ chunks: [([Float], [Float])]) {
        guard !chunks.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            writeWAVChunked(chunks: chunks)
        }
    }

    private static let filenameDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f
    }()

    private static func writeWAVChunked(chunks: [([Float], [Float])]) {
        let filename = "Genesis_\(filenameDateFormatter.string(from: Date())).wav"

        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("recordings")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create recordings directory: \(error.localizedDescription)")
            return
        }
        let url = dir.appendingPathComponent(filename)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: Transport.sampleRate, channels: 2) else {
            logger.error("Failed to create audio format for WAV export")
            return
        }
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            for (left, right) in chunks {
                guard left.count == right.count else { continue }
                let frameCount = AVAudioFrameCount(left.count)
                guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { continue }
                pcmBuffer.frameLength = frameCount
                guard let channelData = pcmBuffer.floatChannelData else { continue }
                left.withUnsafeBufferPointer { ptr in
                    guard let base = ptr.baseAddress else { return }
                    channelData[0].update(from: base, count: left.count)
                }
                right.withUnsafeBufferPointer { ptr in
                    guard let base = ptr.baseAddress else { return }
                    channelData[1].update(from: base, count: right.count)
                }
                try file.write(from: pcmBuffer)
            }
            logger.info("Capture saved: \(filename)")
        } catch {
            logger.error("Failed to write WAV file: \(error.localizedDescription)")
        }
    }
}

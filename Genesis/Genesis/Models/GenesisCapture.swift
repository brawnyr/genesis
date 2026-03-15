import Foundation
import AVFoundation
import os

private let logger = Logger(subsystem: "genesis", category: "GenesisCapture")

struct GenesisCapture {
    enum State {
        case off, on
    }

    var state: State = .off

    // Pre-allocated chunk buffers — avoid per-block heap allocations on audio thread.
    // Only allocates when a chunk fills (~every 10 seconds).
    private static let chunkFrames = 44100 * 10
    private var chunkL: [Float] = []
    private var chunkR: [Float] = []
    private var chunkPos: Int = 0

    // Completed chunks waiting to be written
    private var completedL: [[Float]] = []
    private var completedR: [[Float]] = []

    var accumulatedFrames: Int {
        completedL.reduce(0) { $0 + $1.count } + chunkPos
    }

    mutating func startCapture() {
        state = .on
        completedL = []
        completedR = []
        completedL.reserveCapacity(64)
        completedR.reserveCapacity(64)
        chunkL = [Float](repeating: 0, count: Self.chunkFrames)
        chunkR = [Float](repeating: 0, count: Self.chunkFrames)
        chunkPos = 0
    }

    /// Stop capture and return accumulated chunks for writing.
    /// Call from the thread that owns this struct (under lock if shared).
    mutating func stopCapture() -> [([Float], [Float])] {
        state = .off
        // Flush remaining chunk data
        if chunkPos > 0 {
            completedL.append(Array(chunkL[0..<chunkPos]))
            completedR.append(Array(chunkR[0..<chunkPos]))
        }
        let chunks = zip(completedL, completedR).map { ($0, $1) }
        completedL = []
        completedR = []
        chunkL = []
        chunkR = []
        chunkPos = 0
        return chunks
    }

    /// Append audio from the render callback. Uses pre-allocated chunk buffers
    /// to minimize heap allocations on the audio thread. Only allocates when a
    /// chunk fills (~every 10 seconds).
    mutating func appendFromBuffers(left: UnsafeBufferPointer<Float>, right: UnsafeBufferPointer<Float>) {
        guard state == .on, !chunkL.isEmpty else { return }
        let count = left.count
        var srcOffset = 0
        while srcOffset < count {
            let space = Self.chunkFrames - chunkPos
            let toCopy = min(space, count - srcOffset)
            for i in 0..<toCopy {
                chunkL[chunkPos + i] = left[srcOffset + i]
                chunkR[chunkPos + i] = right[srcOffset + i]
            }
            chunkPos += toCopy
            srcOffset += toCopy
            if chunkPos >= Self.chunkFrames {
                completedL.append(chunkL)
                completedR.append(chunkR)
                chunkL = [Float](repeating: 0, count: Self.chunkFrames)
                chunkR = [Float](repeating: 0, count: Self.chunkFrames)
                chunkPos = 0
            }
        }
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

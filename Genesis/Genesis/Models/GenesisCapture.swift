import Foundation
import AVFoundation
import os

private let logger = Logger(subsystem: "genesis", category: "GenesisCapture")

struct GenesisCapture {
    enum State {
        case off, on
    }

    var state: State = .off
    private var leftBuffers: [[Float]] = []
    private var rightBuffers: [[Float]] = []

    var accumulatedFrames: Int {
        leftBuffers.reduce(0) { $0 + $1.count }
    }

    mutating func toggle() {
        switch state {
        case .off:
            state = .on
            leftBuffers = []
            rightBuffers = []
        case .on:
            writeAndReset()
            state = .off
        }
    }

    mutating func append(left: [Float], right: [Float]) {
        guard state == .on else { return }
        leftBuffers.append(left)
        rightBuffers.append(right)
    }

    /// Append from pre-allocated buffers (avoids creating intermediate arrays).
    mutating func appendFromBuffers(left: UnsafeBufferPointer<Float>, right: UnsafeBufferPointer<Float>) {
        guard state == .on else { return }
        leftBuffers.append(Array(left))
        rightBuffers.append(Array(right))
    }

    private mutating func writeAndReset() {
        guard !leftBuffers.isEmpty else { return }
        let chunks = zip(leftBuffers, rightBuffers).map { ($0, $1) }
        leftBuffers = []
        rightBuffers = []

        DispatchQueue.global(qos: .userInitiated).async {
            Self.writeWAVChunked(chunks: chunks)
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

    private static func writeWAV(left: [Float], right: [Float]) {
        guard left.count == right.count else {
            logger.error("Channel count mismatch: left=\(left.count) right=\(right.count)")
            return
        }
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
            let frameCount = AVAudioFrameCount(left.count)
            guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                logger.error("Failed to create PCM buffer for WAV export")
                return
            }
            pcmBuffer.frameLength = frameCount
            guard let channelData = pcmBuffer.floatChannelData else {
                logger.error("Failed to get float channel data for WAV export")
                return
            }
            left.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return }
                channelData[0].update(from: base, count: left.count)
            }
            right.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return }
                channelData[1].update(from: base, count: right.count)
            }
            try file.write(from: pcmBuffer)
            logger.info("Capture saved: \(filename)")
        } catch {
            logger.error("Failed to write WAV file: \(error.localizedDescription)")
        }
    }
}

import Foundation
import AVFoundation
import os

private let logger = Logger(subsystem: "com.god.capture", category: "GodCapture")

struct GodCapture {
    enum State {
        case idle, armed, recording
    }

    var state: State = .idle
    private var leftBuffers: [[Float]] = []
    private var rightBuffers: [[Float]] = []

    var accumulatedFrames: Int {
        leftBuffers.reduce(0) { $0 + $1.count }
    }

    mutating func toggle() {
        switch state {
        case .idle:
            state = .armed
        case .armed:
            state = .idle
        case .recording:
            writeAndReset()
            state = .idle
        }
    }

    mutating func onLoopBoundary() {
        if state == .armed {
            state = .recording
            leftBuffers = []
            rightBuffers = []
        }
    }

    mutating func append(left: [Float], right: [Float]) {
        guard state == .recording else { return }
        leftBuffers.append(left)
        rightBuffers.append(right)
    }

    private mutating func writeAndReset() {
        guard !leftBuffers.isEmpty else { return }
        let allLeft = leftBuffers.flatMap { $0 }
        let allRight = rightBuffers.flatMap { $0 }
        leftBuffers = []
        rightBuffers = []

        DispatchQueue.global(qos: .userInitiated).async {
            Self.writeWAV(left: allLeft, right: allRight)
        }
    }

    private static let filenameDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f
    }()

    private static func writeWAV(left: [Float], right: [Float]) {
        let filename = "GOD_\(filenameDateFormatter.string(from: Date())).wav"

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
            left.withUnsafeBufferPointer { ptr in
                pcmBuffer.floatChannelData![0].update(from: ptr.baseAddress!, count: left.count)
            }
            right.withUnsafeBufferPointer { ptr in
                pcmBuffer.floatChannelData![1].update(from: ptr.baseAddress!, count: right.count)
            }
            try file.write(from: pcmBuffer)
            logger.info("Capture saved: \(filename)")
        } catch {
            logger.error("Failed to write WAV file: \(error.localizedDescription)")
        }
    }
}

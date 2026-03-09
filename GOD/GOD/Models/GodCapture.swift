import Foundation
import AVFoundation

struct GodCapture {
    enum State {
        case idle, armed, recording
    }

    var state: State = .idle
    private var buffers: [[Float]] = []

    var accumulatedFrames: Int {
        buffers.reduce(0) { $0 + $1.count }
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
            buffers = []
        }
    }

    mutating func append(buffer: [Float]) {
        guard state == .recording else { return }
        buffers.append(buffer)
    }

    private mutating func writeAndReset() {
        guard !buffers.isEmpty else { return }
        let allSamples = buffers.flatMap { $0 }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "GOD_\(formatter.string(from: Date())).wav"

        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".god/captures")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(filename)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        if let file = try? AVAudioFile(forWriting: url, settings: format.settings) {
            let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(allSamples.count))!
            pcmBuffer.frameLength = AVAudioFrameCount(allSamples.count)
            allSamples.withUnsafeBufferPointer { ptr in
                pcmBuffer.floatChannelData![0].update(from: ptr.baseAddress!, count: allSamples.count)
            }
            try? file.write(from: pcmBuffer)
        }

        buffers = []
    }
}

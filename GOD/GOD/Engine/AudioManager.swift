import AVFoundation
import os

private let logger = Logger(subsystem: "god", category: "AudioManager")

enum AudioError: Error {
    case formatCreationFailed
}

class AudioManager {
    private let audioEngine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private weak var godEngine: GodEngine?

    init(engine: GodEngine) {
        self.godEngine = engine
    }

    func start() throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: Transport.sampleRate, channels: 2) else {
            throw AudioError.formatCreationFailed
        }

        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let engine = self?.godEngine else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let leftPtr = ablPointer[0].mData?.assumingMemoryBound(to: Float.self)
            let rightPtr = ablPointer.count >= 2 ? ablPointer[1].mData?.assumingMemoryBound(to: Float.self) : nil

            engine.processBlock(frameCount: Int(frameCount), intoLeft: leftPtr, intoRight: rightPtr)

            return noErr
        }

        self.sourceNode = node
        audioEngine.attach(node)
        audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)

        do {
            try audioEngine.start()
            logger.info("Audio engine started — stereo \(Transport.sampleRate)Hz")
        } catch {
            logger.error("Audio engine failed to start: \(error.localizedDescription)")
            throw error
        }
    }

    func stop() {
        audioEngine.stop()
    }
}

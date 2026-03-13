import AVFoundation
import os

private let logger = Logger(subsystem: "genesis", category: "AudioManager")

enum AudioError: Error {
    case formatCreationFailed
}

class AudioManager {
    private let audioEngine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private weak var genesisEngine: GenesisEngine?

    init(engine: GenesisEngine) {
        self.genesisEngine = engine
    }

    func start() throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: Transport.sampleRate, channels: 2) else {
            throw AudioError.formatCreationFailed
        }

        // Request 128-frame buffer for ~2.9ms latency (M4 handles this easily)
        if let au = audioEngine.outputNode.audioUnit {
            var frames: UInt32 = 128
            let status = AudioUnitSetProperty(au,
                kAudioDevicePropertyBufferFrameSize,
                kAudioUnitScope_Global, 0,
                &frames, UInt32(MemoryLayout<UInt32>.size))
            if status != noErr {
                logger.warning("Could not set buffer size: \(status)")
            }
        }

        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let engine = self?.genesisEngine else { return noErr }

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

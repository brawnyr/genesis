import AVFoundation
import os

private let logger = Logger(subsystem: "com.god.audio", category: "AudioManager")

class AudioManager {
    private let audioEngine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private weak var godEngine: GodEngine?

    init(engine: GodEngine) {
        self.godEngine = engine
    }

    func start() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: Transport.sampleRate, channels: 2)!

        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let engine = self?.godEngine else { return noErr }

            let (left, right) = engine.processBlock(frameCount: Int(frameCount))

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let leftPtr = ablPointer[0].mData?.assumingMemoryBound(to: Float.self)
            let rightPtr: UnsafeMutablePointer<Float>?

            if ablPointer.count >= 2 {
                rightPtr = ablPointer[1].mData?.assumingMemoryBound(to: Float.self)
            } else {
                rightPtr = nil
            }

            for i in 0..<Int(frameCount) {
                let l = i < left.count ? left[i] : 0
                let r = i < right.count ? right[i] : 0
                leftPtr?[i] = l
                rightPtr?[i] = r
            }

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

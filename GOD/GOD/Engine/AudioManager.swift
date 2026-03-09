import AVFoundation

class AudioManager {
    private let audioEngine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private weak var godEngine: GodEngine?

    init(engine: GodEngine) {
        self.godEngine = engine
    }

    func start() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let engine = self?.godEngine else { return noErr }

            let output = engine.processBlock(frameCount: Int(frameCount))

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = ablPointer[0]
            let ptr = buffer.mData?.assumingMemoryBound(to: Float.self)

            for i in 0..<Int(frameCount) {
                if i < output.count {
                    ptr?[i] = output[i]
                } else {
                    ptr?[i] = 0
                }
            }

            return noErr
        }

        self.sourceNode = node
        audioEngine.attach(node)
        audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)

        try audioEngine.start()
    }

    func stop() {
        audioEngine.stop()
    }
}

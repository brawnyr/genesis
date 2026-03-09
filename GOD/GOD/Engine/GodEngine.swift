import Foundation
import Combine

class GodEngine: ObservableObject {
    // UI state — only mutated on main thread
    @Published var transport = Transport()
    @Published var layers: [Layer] = (0..<8).map { Layer(index: $0, name: "PAD \($0 + 1)") }
    @Published var padBank = PadBank()
    @Published var metronome = Metronome()
    @Published var capture = GodCapture()
    @Published var channelSignalLevels: [Float] = Array(repeating: 0, count: 8)
    @Published var channelTriggered: [Bool] = Array(repeating: false, count: 8)

    // Audio thread state — never touches @Published directly
    private var audioPosition: Int = 0
    private var audioIsPlaying: Bool = false
    private var audioBPM: Int = 120
    private var audioBarCount: Int = 4
    private var audioMetronomeOn: Bool = true
    private var audioMetronomeVolume: Float = 0.5
    private var audioLayers: [Layer] = (0..<8).map { Layer(index: $0, name: "PAD \($0 + 1)") }
    private var audioCaptureState: GodCapture.State = .idle
    var voices: [Voice] = []

    private var pendingLevels: [Float] = Array(repeating: 0, count: 8)
    private var uiUpdateCounter = 0

    // Sync UI state to audio thread (called from main thread before audio starts)
    private func syncToAudio() {
        audioIsPlaying = transport.isPlaying
        audioBPM = transport.bpm
        audioBarCount = transport.barCount
        audioPosition = transport.position
        audioMetronomeOn = metronome.isOn
        audioMetronomeVolume = metronome.volume
        audioLayers = layers
        audioCaptureState = capture.state
    }

    func togglePlay() {
        transport.isPlaying.toggle()
        if !transport.isPlaying {
            transport.position = 0
            audioPosition = 0
            audioIsPlaying = false
            voices.removeAll()
        } else {
            audioIsPlaying = true
        }
    }

    func stop() {
        transport.isPlaying = false
        transport.position = 0
        audioPosition = 0
        audioIsPlaying = false
        voices.removeAll()
    }

    func setBPM(_ bpm: Int) {
        transport.bpm = bpm
        audioBPM = transport.bpm
    }

    func toggleMute(layer index: Int) {
        guard index >= 0, index < layers.count else { return }
        layers[index].isMuted.toggle()
        audioLayers[index].isMuted = layers[index].isMuted
    }

    func clearLayer(_ index: Int) {
        guard index >= 0, index < layers.count else { return }
        layers[index].clear()
        audioLayers[index].clear()
    }

    func toggleCapture() {
        capture.toggle()
        audioCaptureState = capture.state
    }

    func toggleMetronome() {
        metronome.isOn.toggle()
        audioMetronomeOn = metronome.isOn
    }

    func onPadHit(note: Int, velocity: Int) {
        guard audioIsPlaying,
              let padIndex = padBank.padIndex(forNote: note),
              let sample = padBank.pads[padIndex].sample else { return }

        layers[padIndex].addHit(at: audioPosition, velocity: velocity)
        audioLayers[padIndex].addHit(at: audioPosition, velocity: velocity)
        layers[padIndex].name = padBank.pads[padIndex].name
        audioLayers[padIndex].name = padBank.pads[padIndex].name

        let vel = Float(velocity) / 127.0
        voices.append(Voice(sample: sample, velocity: vel))

        DispatchQueue.main.async {
            self.channelTriggered[padIndex] = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.channelTriggered[padIndex] = false
            }
        }
    }

    func processBlock(frameCount: Int) -> [Float] {
        var output = [Float](repeating: 0, count: frameCount)
        guard audioIsPlaying else { return output }

        let startPos = audioPosition
        let loopLen = audioLoopLengthFrames

        guard loopLen > 0 else { return output }

        // Check each layer for hits in this block's range
        for layer in audioLayers where !layer.isMuted {
            let endPos = startPos + frameCount
            let hits: [Hit]

            if endPos <= loopLen {
                hits = layer.hits(inRange: startPos..<endPos)
            } else {
                let beforeWrap = layer.hits(inRange: startPos..<loopLen)
                let afterWrap = layer.hits(inRange: 0..<(endPos - loopLen))
                hits = beforeWrap + afterWrap
            }

            for hit in hits {
                if let sample = padBank.pads[layer.index].sample {
                    let vel = Float(hit.velocity) / 127.0
                    voices.append(Voice(sample: sample, velocity: vel))
                }
            }
        }

        // Metronome
        if audioMetronomeOn {
            let beatLen = Metronome.beatLengthFramesStatic(bpm: audioBPM, sampleRate: Transport.sampleRate)
            for i in 0..<frameCount {
                let frameInLoop = (startPos + i) % loopLen
                if beatLen > 0 && frameInLoop % beatLen == 0 {
                    let isDownbeat = frameInLoop == 0
                    let click = Metronome.generateClick(isDownbeat: isDownbeat, sampleRate: Transport.sampleRate)
                    voices.append(Voice(
                        sample: Sample(name: "click", data: click, sampleRate: Transport.sampleRate),
                        velocity: audioMetronomeVolume
                    ))
                }
            }
        }

        // Mix all active voices
        voices = voices.compactMap { voice in
            var v = voice
            let done = v.fill(into: &output, count: frameCount)
            return done ? nil : v
        }

        // Calculate per-channel signal levels (peak detection)
        for voice in voices {
            for i in 0..<8 {
                if let padSample = padBank.pads[i].sample,
                   padSample.name == voice.sample.name {
                    let remaining = min(frameCount, voice.sample.data.count - voice.position)
                    if remaining > 0 {
                        let start = max(0, voice.position)
                        let end = min(voice.sample.data.count, start + remaining)
                        for j in start..<end {
                            pendingLevels[i] = max(pendingLevels[i], abs(voice.sample.data[j] * voice.velocity))
                        }
                    }
                }
            }
        }

        // Advance audio position
        audioPosition += frameCount
        var wrapped = false
        if audioPosition >= loopLen {
            audioPosition -= loopLen
            wrapped = true
        }

        // Capture
        if audioCaptureState == .recording {
            capture.append(buffer: output)
        }
        if wrapped {
            capture.onLoopBoundary()
            audioCaptureState = capture.state
        }

        // Throttle UI updates — sync position + levels ~30x/sec
        uiUpdateCounter += frameCount
        if uiUpdateCounter >= 1323 {
            uiUpdateCounter = 0
            let pos = audioPosition
            let levels = pendingLevels
            pendingLevels = Array(repeating: 0, count: 8)
            DispatchQueue.main.async {
                self.transport.position = pos
                self.channelSignalLevels = levels
            }
        }

        return output
    }

    private var audioLoopLengthFrames: Int {
        let beatsPerLoop = Double(audioBarCount * 4)
        let secondsPerBeat = 60.0 / Double(audioBPM)
        return Int(beatsPerLoop * secondsPerBeat * Transport.sampleRate)
    }

}

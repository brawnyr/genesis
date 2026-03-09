import Foundation
import Combine

class GodEngine: ObservableObject {
    @Published var transport = Transport()
    @Published var layers: [Layer] = (0..<8).map { Layer(index: $0, name: "PAD \($0 + 1)") }
    @Published var padBank = PadBank()
    @Published var metronome = Metronome()
    @Published var capture = GodCapture()
    @Published var channelSignalLevels: [Float] = Array(repeating: 0, count: 8)
    @Published var channelTriggered: [Bool] = Array(repeating: false, count: 8)

    var voices: [Voice] = []

    func togglePlay() {
        transport.isPlaying.toggle()
        if !transport.isPlaying {
            transport.position = 0
            voices.removeAll()
        }
    }

    func stop() {
        transport.isPlaying = false
        transport.position = 0
        voices.removeAll()
    }

    func setBPM(_ bpm: Int) {
        transport.bpm = bpm
    }

    func toggleMute(layer index: Int) {
        guard index >= 0, index < layers.count else { return }
        layers[index].isMuted.toggle()
    }

    func clearLayer(_ index: Int) {
        guard index >= 0, index < layers.count else { return }
        layers[index].clear()
    }

    func toggleCapture() {
        capture.toggle()
    }

    func toggleMetronome() {
        metronome.isOn.toggle()
    }

    func onPadHit(note: Int, velocity: Int) {
        guard transport.isPlaying,
              let padIndex = padBank.padIndex(forNote: note),
              let sample = padBank.pads[padIndex].sample else { return }

        layers[padIndex].addHit(at: transport.position, velocity: velocity)
        layers[padIndex].name = padBank.pads[padIndex].name

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
        guard transport.isPlaying else { return output }

        let startPos = transport.position
        let loopLen = transport.loopLengthFrames

        // Check each layer for hits in this block's range
        for layer in layers where !layer.isMuted {
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
        if metronome.isOn {
            let beatLen = metronome.beatLengthFrames(bpm: transport.bpm, sampleRate: Transport.sampleRate)
            for i in 0..<frameCount {
                let frameInLoop = (startPos + i) % loopLen
                if beatLen > 0 && frameInLoop % beatLen == 0 {
                    let isDownbeat = frameInLoop == 0
                    let click = Metronome.generateClick(isDownbeat: isDownbeat, sampleRate: Transport.sampleRate)
                    voices.append(Voice(
                        sample: Sample(name: "click", data: click, sampleRate: Transport.sampleRate),
                        velocity: metronome.volume
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
        var newLevels = Array<Float>(repeating: 0, count: 8)
        for voice in voices {
            for i in 0..<8 {
                if let padSample = padBank.pads[i].sample,
                   padSample.name == voice.sample.name {
                    let remaining = min(frameCount, voice.sample.data.count - voice.position)
                    if remaining > 0 {
                        let start = max(0, voice.position)
                        let end = min(voice.sample.data.count, start + remaining)
                        for j in start..<end {
                            newLevels[i] = max(newLevels[i], abs(voice.sample.data[j] * voice.velocity))
                        }
                    }
                }
            }
        }

        DispatchQueue.main.async { [newLevels] in
            self.channelSignalLevels = newLevels
        }

        // Capture
        if capture.state == .recording {
            capture.append(buffer: output)
        }

        // Advance transport
        let wrapped = transport.advance(frames: frameCount)
        if wrapped {
            capture.onLoopBoundary()
        }

        return output
    }

    func executeCommand(_ input: String) {
        let parts = input.lowercased().trimmingCharacters(in: .whitespaces).split(separator: " ")
        guard let cmd = parts.first else { return }

        switch cmd {
        case "play":
            if !transport.isPlaying { togglePlay() }
        case "stop":
            stop()
        case "god":
            toggleCapture()
        case "bpm":
            if let val = parts.dropFirst().first, let bpm = Int(val) {
                setBPM(bpm)
            }
        case "mute":
            if let val = parts.dropFirst().first, let idx = Int(val) {
                if idx >= 1, idx <= 8 { toggleMute(layer: idx - 1) }
            }
        case "unmute":
            if let val = parts.dropFirst().first, let idx = Int(val) {
                if idx >= 1, idx <= 8, layers[idx - 1].isMuted {
                    toggleMute(layer: idx - 1)
                }
            }
        case "clear":
            if let val = parts.dropFirst().first, let idx = Int(val) {
                if idx >= 1, idx <= 8 { clearLayer(idx - 1) }
            }
        default:
            break
        }
    }
}

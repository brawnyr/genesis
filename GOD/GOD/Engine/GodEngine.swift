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
    @Published var masterLevel: Float = 0
    var masterVolume: Float = 1.0
    @Published var activePadIndex: Int = 0

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
    let midiRingBuffer = MIDIRingBuffer()


    private var pendingLevels: [Float] = Array(repeating: 0, count: 8)
    private var pendingTriggers: [Bool] = Array(repeating: false, count: 8)
    private var pendingHits: [(padIndex: Int, position: Int, velocity: Int)] = []
    private var uiUpdateCounter = 0
    private var lastClearedLayerIndex: Int?
    private var audioActivePadIndex: Int = 0

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

    func setBarCount(_ count: Int) {
        transport.barCount = count
        audioBarCount = transport.barCount
    }

    func cycleBarCount(forward: Bool) {
        let options = [1, 2, 4]
        if let idx = options.firstIndex(of: transport.barCount) {
            let next = forward ? min(idx + 1, options.count - 1) : max(idx - 1, 0)
            setBarCount(options[next])
        }
    }

    func adjustMasterVolume(_ delta: Float) {
        masterVolume = max(0, min(2.0, masterVolume + delta))
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
        lastClearedLayerIndex = index
    }

    func undoLastClear() {
        guard let index = lastClearedLayerIndex else { return }
        layers[index].undo()
        audioLayers[index].undo()
        lastClearedLayerIndex = nil
    }

    func toggleCapture() {
        capture.toggle()
        audioCaptureState = capture.state
    }

    func toggleMetronome() {
        metronome.isOn.toggle()
        audioMetronomeOn = metronome.isOn
    }

    private func handlePadHit(note: Int, velocity: Int) {
        guard let padIndex = padBank.padIndex(forNote: note),
              let sample = padBank.pads[padIndex].sample else { return }

        audioActivePadIndex = padIndex
        audioLayers[padIndex].addHit(at: audioPosition, velocity: velocity)
        audioLayers[padIndex].name = padBank.pads[padIndex].name

        let vel = Float(velocity) / 127.0 * audioLayers[padIndex].volume
        voices.append(Voice(sample: sample, velocity: vel, padIndex: padIndex))

        pendingHits.append((padIndex: padIndex, position: audioPosition, velocity: velocity))
        pendingTriggers[padIndex] = true
    }

    private func handleNoteOff(note: Int) {
        guard let padIndex = padBank.padIndex(forNote: note) else { return }
        guard !padBank.pads[padIndex].isOneShot else { return }
        voices.removeAll { $0.padIndex == padIndex }
    }

    private func handleCC(number: Int, value: Int) {
        switch number {
        case 14: // Volume
            audioLayers[audioActivePadIndex].volume = Float(value) / 127.0
        case 15: // Pan
            audioLayers[audioActivePadIndex].pan = Float(value) / 127.0
        case 16: // HP Cutoff
            audioLayers[audioActivePadIndex].hpCutoff = ccToFrequency(value)
        case 17: // LP Cutoff
            audioLayers[audioActivePadIndex].lpCutoff = ccToFrequency(value)
        default:
            break
        }
    }

    func processBlock(frameCount: Int) -> (left: [Float], right: [Float]) {
        var outputL = [Float](repeating: 0, count: frameCount)
        var outputR = [Float](repeating: 0, count: frameCount)
        guard audioIsPlaying else { return (outputL, outputR) }

        let startPos = audioPosition
        let loopLen = audioLoopLengthFrames

        guard loopLen > 0 else { return (outputL, outputR) }

        // Drain MIDI events from ring buffer
        midiRingBuffer.drain { event in
            switch event {
            case .noteOn(let note, let velocity):
                handlePadHit(note: note, velocity: velocity)
            case .noteOff(let note):
                handleNoteOff(note: note)
            case .cc(let number, let value):
                handleCC(number: number, value: value)
            }
        }

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
                    let vel = Float(hit.velocity) / 127.0 * layer.volume
                    voices.append(Voice(sample: sample, velocity: vel, padIndex: layer.index))
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
                    voices.append(Voice(sample: click, velocity: audioMetronomeVolume))
                }
            }
        }

        // Mix all active voices — track per-channel peak during fill
        voices = voices.compactMap { voice in
            var v = voice
            let layer = v.padIndex >= 0 && v.padIndex < 8 ? audioLayers[v.padIndex] : nil
            let hpCoeffs = (layer?.hpCutoff ?? 20) <= 21
                ? BiquadCoefficients.bypass
                : BiquadCoefficients.highPass(cutoff: layer!.hpCutoff, sampleRate: Float(Transport.sampleRate))
            let lpCoeffs = (layer?.lpCutoff ?? 20000) >= 19999
                ? BiquadCoefficients.bypass
                : BiquadCoefficients.lowPass(cutoff: layer!.lpCutoff, sampleRate: Float(Transport.sampleRate))
            let pan = layer?.pan ?? 0.5
            let (done, peak) = v.fill(intoLeft: &outputL, right: &outputR, count: frameCount,
                                       pan: pan, hpCoeffs: hpCoeffs, lpCoeffs: lpCoeffs)
            if v.padIndex >= 0 && v.padIndex < 8 {
                pendingLevels[v.padIndex] = max(pendingLevels[v.padIndex], peak)
            }
            return done ? nil : v
        }

        // Apply master volume and track master level
        var peak: Float = 0
        for i in 0..<frameCount {
            outputL[i] *= masterVolume
            outputR[i] *= masterVolume
            peak = max(peak, abs(outputL[i]), abs(outputR[i]))
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
            capture.append(left: outputL, right: outputR)
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
            let masterPeak = peak
            let triggers = pendingTriggers
            let layerVolumes = audioLayers.map { $0.volume }
            let activePad = audioActivePadIndex
            let layerPans = audioLayers.map { $0.pan }
            let layerHPCutoffs = audioLayers.map { $0.hpCutoff }
            let layerLPCutoffs = audioLayers.map { $0.lpCutoff }
            let hits = pendingHits
            pendingHits.removeAll()
            pendingLevels = Array(repeating: 0, count: 8)
            pendingTriggers = Array(repeating: false, count: 8)
            DispatchQueue.main.async {
                for hit in hits {
                    self.layers[hit.padIndex].addHit(at: hit.position, velocity: hit.velocity)
                    self.layers[hit.padIndex].name = self.padBank.pads[hit.padIndex].name
                }
                self.transport.position = pos
                self.channelSignalLevels = levels
                self.masterLevel = masterPeak
                self.activePadIndex = activePad
                for i in 0..<8 {
                    if triggers[i] {
                        self.channelTriggered[i] = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.channelTriggered[i] = false
                        }
                    }
                    self.layers[i].volume = layerVolumes[i]
                    self.layers[i].pan = layerPans[i]
                    self.layers[i].hpCutoff = layerHPCutoffs[i]
                    self.layers[i].lpCutoff = layerLPCutoffs[i]
                }
            }
        }

        return (outputL, outputR)
    }

    private var audioLoopLengthFrames: Int {
        let beatsPerLoop = Double(audioBarCount * 4)
        let secondsPerBeat = 60.0 / Double(audioBPM)
        return Int(beatsPerLoop * secondsPerBeat * Transport.sampleRate)
    }

}

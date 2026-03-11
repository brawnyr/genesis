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
    @Published var masterVolume: Float = 1.0
    @Published var detectedBPMs: [Int: Double] = [:]
    @Published var activePadIndex: Int = 0
    var interpreter: EngineEventInterpreter?

    // Audio thread state — never touches @Published directly
    private var audioPosition: Int = 0
    private var audioIsPlaying: Bool = false
    private var audioBPM: Int = 120
    private var audioBarCount: Int = 4
    private var audioMetronomeOn: Bool = true
    private var audioMetronomeVolume: Float = 0.5
    private var audioLayers: [Layer] = (0..<8).map { Layer(index: $0, name: "PAD \($0 + 1)") }
    private var audioCaptureState: GodCapture.State = .idle
    private var audioCapture = GodCapture()
    private(set) var voices: [Voice] = []
    let midiRingBuffer = MIDIRingBuffer()

    // UI update throttle: 44100 / 1323 ≈ 33Hz (~30fps)
    private static let uiUpdateFrameThreshold = 1323

    private var pendingLevels: [Float] = Array(repeating: 0, count: 8)
    private var pendingTriggers: [Bool] = Array(repeating: false, count: 8)
    private var pendingHits: [(padIndex: Int, position: Int, velocity: Int)] = []
    private var uiUpdateCounter = 0
    private var lastClearedLayerIndex: Int?
    private var audioActivePadIndex: Int = 0

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

    func setMasterVolume(_ value: Float) {
        masterVolume = max(0, min(1.0, value))
    }

    func detectBPM(forPad index: Int) {
        guard let sample = padBank.pads[index].sample else {
            detectedBPMs[index] = nil
            return
        }
        let buffer = sample.left
        let sampleRate = sample.sampleRate
        detectedBPMs[index] = nil  // clear while detecting
        Task.detached { [weak self] in
            let bpm = BPMDetector.detect(buffer: buffer, sampleRate: sampleRate)
            await MainActor.run {
                self?.detectedBPMs[index] = bpm
            }
        }
    }

    func setLayerVolume(_ index: Int, volume: Float) {
        guard index >= 0, index < layers.count else { return }
        layers[index].volume = max(0, min(1.0, volume))
    }

    var loopDurationMs: Double {
        Double(transport.loopLengthFrames) / Transport.sampleRate * 1000.0
    }

    func toggleMute(layer index: Int) {
        guard index >= 0, index < layers.count else { return }
        layers[index].isMuted.toggle()
        audioLayers[index].isMuted = layers[index].isMuted
    }

    func toggleCut(pad index: Int) {
        guard index >= 0, index < layers.count else { return }
        layers[index].cut.toggle()
        audioLayers[index].cut = layers[index].cut
    }

    func syncCutToPadBank() {
        for i in 0..<8 {
            padBank.pads[i].cut = layers[i].cut
        }
    }

    func restoreCutFromPadBank() {
        for i in 0..<8 {
            layers[i].cut = padBank.pads[i].cut
            audioLayers[i].cut = padBank.pads[i].cut
        }
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
        audioCapture = capture
    }

    func toggleMetronome() {
        metronome.isOn.toggle()
        audioMetronomeOn = metronome.isOn
    }

    private func handlePadHit(note: Int, velocity: Int, record: Bool) {
        guard let padIndex = padBank.padIndex(forNote: note),
              let sample = padBank.pads[padIndex].sample else { return }

        audioActivePadIndex = padIndex

        // Only record hits to layer when transport is playing
        if record {
            audioLayers[padIndex].addHit(at: audioPosition, velocity: velocity)
            audioLayers[padIndex].name = padBank.pads[padIndex].name
        }

        if audioLayers[padIndex].cut {
            voices.removeAll { $0.padIndex == padIndex }
        }
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

        let loopLen = audioLoopLengthFrames

        // Loop replay, metronome, capture, and position advance only when playing
        if audioIsPlaying, loopLen > 0 {
            let startPos = audioPosition

            // Check each layer for hits in this block's range (before draining MIDI,
            // so live hits recorded this block don't retrigger via the loop path)
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
                        if layer.cut {
                            voices.removeAll { $0.padIndex == layer.index }
                        }
                        let vel = Float(hit.velocity) / 127.0 * layer.volume
                        voices.append(Voice(sample: sample, velocity: vel, padIndex: layer.index))
                    }
                }
            }

            // Drain MIDI events from ring buffer (after loop scan to avoid double-triggering)
            midiRingBuffer.drain { event in
                switch event {
                case .noteOn(let note, let velocity):
                    handlePadHit(note: note, velocity: velocity, record: true)
                case .noteOff(let note):
                    handleNoteOff(note: note)
                case .cc(let number, let value):
                    handleCC(number: number, value: value)
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

            // Advance audio position
            audioPosition += frameCount
            var wrapped = false
            if audioPosition >= loopLen {
                audioPosition -= loopLen
                wrapped = true
            }

            // Capture
            if audioCaptureState == .recording {
                audioCapture.append(left: outputL, right: outputR)
            }
            if wrapped {
                audioCapture.onLoopBoundary()
                audioCaptureState = audioCapture.state
                let captureState = audioCaptureState
                DispatchQueue.main.async {
                    self.capture.state = captureState
                    self.interpreter?.onLoopBoundary(
                        layers: self.layers,
                        padBank: self.padBank,
                        loopDurationMs: self.loopDurationMs
                    )
                }
            }
        } else {
            // Transport stopped — still drain MIDI for pad auditioning (no recording)
            midiRingBuffer.drain { event in
                switch event {
                case .noteOn(let note, let velocity):
                    handlePadHit(note: note, velocity: velocity, record: false)
                case .noteOff(let note):
                    handleNoteOff(note: note)
                case .cc(let number, let value):
                    handleCC(number: number, value: value)
                }
            }
        }

        // Mix all active voices — always, even when stopped (for pad auditioning)
        voices = voices.compactMap { voice in
            var v = voice
            let layer = v.padIndex >= 0 && v.padIndex < 8 ? audioLayers[v.padIndex] : nil
            let hpCutoff = layer?.hpCutoff ?? 20
            let lpCutoff = layer?.lpCutoff ?? 20000
            let hpCoeffs = hpCutoff <= 21
                ? BiquadCoefficients.bypass
                : BiquadCoefficients.highPass(cutoff: hpCutoff, sampleRate: Float(Transport.sampleRate))
            let lpCoeffs = lpCutoff >= 19999
                ? BiquadCoefficients.bypass
                : BiquadCoefficients.lowPass(cutoff: lpCutoff, sampleRate: Float(Transport.sampleRate))
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

        // Throttle UI updates — sync position + levels ~30x/sec
        uiUpdateCounter += frameCount
        if uiUpdateCounter >= Self.uiUpdateFrameThreshold {
            uiUpdateCounter = 0
            let pos = audioPosition
            let levels = pendingLevels
            let masterPeak = peak
            let triggers = pendingTriggers
            let layerVolumes = audioLayers.map { $0.volume }
            audioActivePadIndex = activePadIndex
            let layerPans = audioLayers.map { $0.pan }
            let layerHPCutoffs = audioLayers.map { $0.hpCutoff }
            let layerLPCutoffs = audioLayers.map { $0.lpCutoff }
            let hits = pendingHits
            pendingHits.removeAll()
            pendingLevels = Array(repeating: 0, count: 8)
            pendingTriggers = Array(repeating: false, count: 8)
            DispatchQueue.main.async {
                if self.audioIsPlaying {
                    for hit in hits {
                        self.layers[hit.padIndex].addHit(at: hit.position, velocity: hit.velocity)
                        self.layers[hit.padIndex].name = self.padBank.pads[hit.padIndex].name
                    }
                }
                self.transport.position = pos
                self.channelSignalLevels = levels
                self.masterLevel = masterPeak
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
                if let interp = self.interpreter {
                    let activeVoicePads = Set(self.voices.filter { $0.padIndex >= 0 }.map(\.padIndex))
                    interp.activePadVoices = activeVoicePads

                    interp.processHits(hits, padBank: self.padBank, loopDurationMs: self.loopDurationMs)
                    interp.processStateDiff(
                        layers: self.layers,
                        transport: self.transport,
                        capture: self.capture,
                        padBank: self.padBank,
                        masterVolume: self.masterVolume
                    )
                    interp.tickVisuals()
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

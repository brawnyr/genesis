import Foundation
import Combine

enum ToggleMode: String {
    case instant = "instant"
    case nextLoop = "next loop"
}

/// All state owned exclusively by the audio thread.
/// Never access @Published properties from here. Sync to main thread via DispatchQueue.main.async.
struct AudioState {
    var position: Int = 0
    var isPlaying: Bool = false
    var bpm: Int = 120
    var barCount: Int = 4
    var metronomeOn: Bool = true
    var metronomeVolume: Float = 0.5
    var layers: [Layer] = (0..<PadBank.padCount).map { Layer(index: $0, name: "PAD \($0 + 1)") }
    var captureState: GodCapture.State = .idle
    var capture = GodCapture()
    var activePadIndex: Int = 0
    var toggleMode: ToggleMode = .instant
    var pendingMutes: [Int: Bool] = [:]

    var loopLengthFrames: Int {
        let beatsPerLoop = Double(barCount * Transport.beatsPerBar)
        let secondsPerBeat = 60.0 / Double(bpm)
        return Int(beatsPerLoop * secondsPerBeat * Transport.sampleRate)
    }
}

class GodEngine: ObservableObject {
    // MARK: - UI state (main thread only, observed by SwiftUI)

    @Published var transport = Transport()
    @Published var layers: [Layer] = (0..<PadBank.padCount).map { Layer(index: $0, name: "PAD \($0 + 1)") }
    @Published var padBank = PadBank()
    @Published var metronome = Metronome()
    @Published var capture = GodCapture()
    @Published var channelSignalLevels: [Float] = Array(repeating: 0, count: PadBank.padCount)
    @Published var channelTriggered: [Bool] = Array(repeating: false, count: PadBank.padCount)
    @Published var masterLevel: Float = 0
    @Published var masterLevelDb: Float = -.infinity
    @Published var channelLevelDb: [Float] = Array(repeating: -.infinity, count: PadBank.padCount)
    @Published var masterVolume: Float = 1.0
    @Published var detectedBPMs: [Int: Double] = [:]
    @Published var activePadIndex: Int = 0
    @Published var toggleMode: ToggleMode = .instant
    @Published var pendingMutes: [Int: Bool] = [:]  // pad index -> target mute state
    var interpreter: EngineEventInterpreter?

    // MARK: - Audio thread state (never touch @Published from here)

    private var audio = AudioState()
    private(set) var voices: [Voice] = []
    let midiRingBuffer = MIDIRingBuffer()

    // MARK: - Audio thread buffers (pre-allocated, avoid heap allocs)

    private var outputBufferL = [Float](repeating: 0, count: 4096)
    private var outputBufferR = [Float](repeating: 0, count: 4096)

    // MARK: - Cached biquad coefficients (recalculated only on cutoff change)

    private var cachedHPCutoffs: [Float] = Array(repeating: Layer.hpBypassFrequency, count: PadBank.padCount)
    private var cachedLPCutoffs: [Float] = Array(repeating: Layer.lpBypassFrequency, count: PadBank.padCount)
    private var cachedHPCoeffs: [BiquadCoefficients] = Array(repeating: .bypass, count: PadBank.padCount)
    private var cachedLPCoeffs: [BiquadCoefficients] = Array(repeating: .bypass, count: PadBank.padCount)

    // MARK: - UI sync throttle

    private static let uiUpdateHz: Double = 33.0
    private static let uiUpdateFrameThreshold = Int(Transport.sampleRate / uiUpdateHz)

    private var pendingLevels: [Float] = Array(repeating: 0, count: PadBank.padCount)
    private var pendingTriggers: [Bool] = Array(repeating: false, count: PadBank.padCount)
    private var pendingHits: [(padIndex: Int, position: Int, velocity: Int)] = []
    private var uiUpdateCounter = 0
    private var lastClearedLayerIndex: Int?

    func togglePlay() {
        transport.isPlaying.toggle()
        if !transport.isPlaying {
            transport.position = 0
            audio.position = 0
            audio.isPlaying = false
            voices.removeAll()
        } else {
            audio.isPlaying = true
        }
    }

    func stop() {
        transport.isPlaying = false
        transport.position = 0
        audio.position = 0
        audio.isPlaying = false
        voices.removeAll()
    }

    func setBPM(_ bpm: Int) {
        transport.bpm = bpm
        audio.bpm = transport.bpm
    }

    func setBarCount(_ count: Int) {
        transport.barCount = count
        audio.barCount = transport.barCount
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
        detectedBPMs[index] = nil
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
        if toggleMode == .instant {
            layers[index].isMuted.toggle()
            audio.layers[index].isMuted = layers[index].isMuted
        } else {
            // Next loop mode: queue the change
            let currentEffective = pendingMutes[index] ?? layers[index].isMuted
            let newState = !currentEffective
            if newState == layers[index].isMuted {
                // Toggling back to current state = cancel pending
                pendingMutes.removeValue(forKey: index)
                audio.pendingMutes.removeValue(forKey: index)
            } else {
                pendingMutes[index] = newState
                audio.pendingMutes[index] = newState
            }
        }
    }

    /// The effective mute state accounting for pending changes
    func effectiveMuteState(layer index: Int) -> Bool {
        pendingMutes[index] ?? layers[index].isMuted
    }

    func cycleToggleMode() {
        toggleMode = toggleMode == .instant ? .nextLoop : .instant
        audio.toggleMode = toggleMode
        if toggleMode == .instant {
            // Apply any pending mutes immediately when switching to instant
            for (index, muteState) in pendingMutes {
                layers[index].isMuted = muteState
                audio.layers[index].isMuted = muteState
            }
            pendingMutes.removeAll()
            audio.pendingMutes.removeAll()
        }
    }

    func toggleCut(pad index: Int) {
        guard index >= 0, index < layers.count else { return }
        layers[index].cut.toggle()
        audio.layers[index].cut = layers[index].cut
    }

    func syncCutToPadBank() {
        for i in 0..<PadBank.padCount {
            padBank.pads[i].cut = layers[i].cut
        }
    }

    func restoreCutFromPadBank() {
        for i in 0..<PadBank.padCount {
            layers[i].cut = padBank.pads[i].cut
            audio.layers[i].cut = padBank.pads[i].cut
        }
    }

    func clearLayer(_ index: Int) {
        guard index >= 0, index < layers.count else { return }
        layers[index].clear()
        audio.layers[index].clear()
        lastClearedLayerIndex = index
    }

    func undoLastClear() {
        guard let index = lastClearedLayerIndex else { return }
        layers[index].undo()
        audio.layers[index].undo()
        lastClearedLayerIndex = nil
    }

    func toggleCapture() {
        capture.toggle()
        audio.captureState = capture.state
        audio.capture = capture
    }

    func toggleMetronome() {
        metronome.isOn.toggle()
        audio.metronomeOn = metronome.isOn
    }

    // MARK: - Centralized sample loading (single source of truth)

    func loadSample(from url: URL, forPad index: Int) throws {
        let sample = try Sample.load(from: url)
        padBank.assign(sample: sample, toPad: index)
        padBank.pads[index].samplePath = url.path
        layers[index].name = sample.name.uppercased()
        syncCutToPadBank()
        do {
            try padBank.save()
        } catch {
            // Non-fatal: config save failure doesn't affect playback
        }
        detectBPM(forPad: index)
    }

    // MARK: - Audio thread

    private func handlePadHit(note: Int, velocity: Int, record: Bool) {
        guard let padIndex = padBank.padIndex(forNote: note),
              let sample = padBank.pads[padIndex].sample else { return }

        audio.activePadIndex = padIndex

        if record {
            audio.layers[padIndex].addHit(at: audio.position, velocity: velocity)
            audio.layers[padIndex].name = padBank.pads[padIndex].name
        }

        if audio.layers[padIndex].cut {
            voices.removeAll { $0.padIndex == padIndex }
        }
        let vel = Float(velocity) / 127.0
        voices.append(Voice(sample: sample, velocity: vel, padIndex: padIndex))

        pendingHits.append((padIndex: padIndex, position: audio.position, velocity: velocity))
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
            audio.layers[audio.activePadIndex].volume = Float(value) / 127.0
        case 15: // Pan
            audio.layers[audio.activePadIndex].pan = Float(value) / 127.0
        case 16: // HP Cutoff
            audio.layers[audio.activePadIndex].hpCutoff = ccToFrequency(value)
        case 17: // LP Cutoff
            audio.layers[audio.activePadIndex].lpCutoff = ccToFrequency(value)
        default:
            break
        }
    }

    private func updateCachedCoefficients() {
        let sr = Float(Transport.sampleRate)
        for i in 0..<PadBank.padCount {
            let hp = audio.layers[i].hpCutoff
            if hp != cachedHPCutoffs[i] {
                cachedHPCutoffs[i] = hp
                cachedHPCoeffs[i] = hp <= 21 ? .bypass : .highPass(cutoff: hp, sampleRate: sr)
            }
            let lp = audio.layers[i].lpCutoff
            if lp != cachedLPCutoffs[i] {
                cachedLPCutoffs[i] = lp
                cachedLPCoeffs[i] = lp >= 19999 ? .bypass : .lowPass(cutoff: lp, sampleRate: sr)
            }
        }
    }

    func processBlock(frameCount: Int) -> (left: [Float], right: [Float]) {
        // Ensure pre-allocated buffers are large enough, then zero them
        if outputBufferL.count < frameCount {
            outputBufferL = [Float](repeating: 0, count: frameCount)
            outputBufferR = [Float](repeating: 0, count: frameCount)
        } else {
            for i in 0..<frameCount {
                outputBufferL[i] = 0
                outputBufferR[i] = 0
            }
        }

        let loopLen = audio.loopLengthFrames

        // Loop replay, metronome, and position advance only when playing
        var wrapped = false
        if audio.isPlaying, loopLen > 0 {
            let startPos = audio.position

            // Check each layer for hits in this block's range (before draining MIDI,
            // so live hits recorded this block don't retrigger via the loop path)
            for layer in audio.layers where !layer.isMuted {
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
                        let vel = Float(hit.velocity) / 127.0
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
            if audio.metronomeOn {
                let beatLen = Metronome.beatLengthFramesStatic(bpm: audio.bpm, sampleRate: Transport.sampleRate)
                for i in 0..<frameCount {
                    let frameInLoop = (startPos + i) % loopLen
                    if beatLen > 0 && frameInLoop % beatLen == 0 {
                        let isDownbeat = frameInLoop == 0
                        let click = Metronome.generateClick(isDownbeat: isDownbeat, sampleRate: Transport.sampleRate)
                        voices.append(Voice(sample: click, velocity: audio.metronomeVolume))
                    }
                }
            }

            // Advance audio position
            audio.position += frameCount
            if audio.position >= loopLen {
                audio.position -= loopLen
                wrapped = true
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

        // Update cached biquad coefficients (only recalculates when cutoffs change)
        updateCachedCoefficients()

        // Mix all active voices — always, even when stopped (for pad auditioning)
        voices = voices.compactMap { voice in
            var v = voice
            let padIdx = v.padIndex
            let hpCoeffs = padIdx >= 0 && padIdx < PadBank.padCount ? cachedHPCoeffs[padIdx] : .bypass
            let lpCoeffs = padIdx >= 0 && padIdx < PadBank.padCount ? cachedLPCoeffs[padIdx] : .bypass
            let pan = padIdx >= 0 && padIdx < PadBank.padCount ? audio.layers[padIdx].pan : 0.5
            let volume = padIdx >= 0 && padIdx < PadBank.padCount ? audio.layers[padIdx].volume : 1.0
            let (done, peak) = v.fill(intoLeft: &outputBufferL, right: &outputBufferR, count: frameCount,
                                       pan: pan, volume: volume, hpCoeffs: hpCoeffs, lpCoeffs: lpCoeffs)
            if padIdx >= 0 && padIdx < PadBank.padCount {
                pendingLevels[padIdx] = max(pendingLevels[padIdx], peak)
            }
            return done ? nil : v
        }

        // Apply master volume and track master level
        var peak: Float = 0
        for i in 0..<frameCount {
            outputBufferL[i] *= masterVolume
            outputBufferR[i] *= masterVolume
            peak = max(peak, abs(outputBufferL[i]), abs(outputBufferR[i]))
        }

        // Capture AFTER mixing — so we record actual audio, not silence
        if audio.captureState == .recording {
            audio.capture.append(
                left: Array(outputBufferL[0..<frameCount]),
                right: Array(outputBufferR[0..<frameCount])
            )
        }

        if wrapped {
            // Apply pending mute changes at loop boundary
            if !audio.pendingMutes.isEmpty {
                let applied = audio.pendingMutes
                for (index, muteState) in applied {
                    audio.layers[index].isMuted = muteState
                }
                audio.pendingMutes.removeAll()
                DispatchQueue.main.async {
                    for (index, muteState) in applied {
                        self.layers[index].isMuted = muteState
                    }
                    self.pendingMutes.removeAll()
                }
            }

            audio.capture.onLoopBoundary()
            audio.captureState = audio.capture.state
            let captureState = audio.captureState
            DispatchQueue.main.async {
                self.capture.state = captureState
                self.interpreter?.onLoopBoundary(
                    layers: self.layers,
                    padBank: self.padBank,
                    loopDurationMs: self.loopDurationMs
                )
            }
        }

        // Throttle UI updates — sync position + levels ~30x/sec
        uiUpdateCounter += frameCount
        if uiUpdateCounter >= Self.uiUpdateFrameThreshold {
            uiUpdateCounter = 0
            let pos = audio.position
            let levels = pendingLevels
            let masterPeak = peak
            let triggers = pendingTriggers
            let layerVolumes = audio.layers.map { $0.volume }
            let layerPans = audio.layers.map { $0.pan }
            let layerHPCutoffs = audio.layers.map { $0.hpCutoff }
            let layerLPCutoffs = audio.layers.map { $0.lpCutoff }
            let hits = pendingHits
            pendingHits.removeAll()
            pendingLevels = Array(repeating: 0, count: PadBank.padCount)
            pendingTriggers = Array(repeating: false, count: PadBank.padCount)
            DispatchQueue.main.async {
                // Sync active pad index from main → audio thread (safe direction)
                self.audio.activePadIndex = self.activePadIndex

                if self.audio.isPlaying {
                    for hit in hits {
                        self.layers[hit.padIndex].addHit(at: hit.position, velocity: hit.velocity)
                        self.layers[hit.padIndex].name = self.padBank.pads[hit.padIndex].name
                    }
                }
                self.transport.position = pos
                self.channelSignalLevels = levels
                self.masterLevel = masterPeak
                self.masterLevelDb = linearToDb(masterPeak)
                self.channelLevelDb = levels.map { linearToDb($0) }
                for i in 0..<PadBank.padCount {
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

        return (Array(outputBufferL[0..<frameCount]), Array(outputBufferR[0..<frameCount]))
    }
}

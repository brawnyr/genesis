import Foundation
import os

enum ToggleMode: String {
    case instant = "instant"
    case nextLoop = "next loop"
}

enum VelocityMode: String {
    case pressure = "pressure"
    case full = "full"
}

/// All state owned exclusively by the audio thread.
/// Never access @Published properties from here. Sync to main thread via DispatchQueue.main.async.
struct AudioState {
    var position: Int = 0
    var isPlaying: Bool = false
    var bpm: Int = 165
    var barCount: Int = 4
    var metronomeOn: Bool = true
    var metronomeVolume: Float = 0.5
    var layers: [Layer] = (0..<PadBank.padCount).map { Layer(index: $0, name: "PAD \($0 + 1)") }
    var captureState: GenesisCapture.State = .off
    var capture = GenesisCapture()
    var activePadIndex: Int = 0
    var toggleMode: ToggleMode = .instant
    var pendingMutes: [Int: Bool] = [:]
    var masterVolume: Float = 1.0

    var loopLengthFrames: Int {
        let beatsPerLoop = Double(barCount * Transport.beatsPerBar)
        let secondsPerBeat = 60.0 / Double(bpm)
        return Int(beatsPerLoop * secondsPerBeat * Transport.sampleRate)
    }
}

class GenesisEngine: ObservableObject {
    // MARK: - UI state (main thread only, observed by SwiftUI)

    @Published var transport = Transport()
    @Published var layers: [Layer] = (0..<PadBank.padCount).map { Layer(index: $0, name: "PAD \($0 + 1)") }
    @Published var padBank = PadBank()
    @Published var metronome = Metronome()
    @Published var capture = GenesisCapture()
    @Published var channelSignalLevels: [Float] = Array(repeating: 0, count: PadBank.padCount)
    @Published var channelTriggered: [Bool] = Array(repeating: false, count: PadBank.padCount)
    @Published var masterLevel: Float = 0
    @Published var masterLevelDb: Float = -.infinity
    @Published var channelLevelDb: [Float] = Array(repeating: -.infinity, count: PadBank.padCount)
    @Published var masterVolume: Float = GenesisEngine.loadMasterVolume()
    @Published var detectedBPMs: [Int: Double] = [:]
    @Published var activePadIndex: Int = 0 {
        didSet {
            os_unfair_lock_lock(&audioLock)
            audio.activePadIndex = activePadIndex
            os_unfair_lock_unlock(&audioLock)
        }
    }
    @Published var toggleMode: ToggleMode = .instant
    @Published var velocityMode: VelocityMode = .pressure
    @Published var pendingMutes: [Int: Bool] = [:]  // pad index -> target mute state
    var interpreter: EngineEventInterpreter?

    // MARK: - Audio thread state (never touch @Published from here)

    var audio = AudioState(masterVolume: GenesisEngine.loadMasterVolume())
    var voicePool = VoicePool()
    let midiRingBuffer = MIDIRingBuffer()
    var audioLock = os_unfair_lock()

    // MARK: - Audio thread buffers (pre-allocated, avoid heap allocs)

    var outputBufferL = [Float](repeating: 0, count: 4096)
    var outputBufferR = [Float](repeating: 0, count: 4096)

    // MARK: - Cached biquad coefficients (recalculated only on cutoff change)

    var cachedHPCutoffs: [Float] = Array(repeating: Layer.hpBypassFrequency, count: PadBank.padCount)
    var cachedLPCutoffs: [Float] = Array(repeating: Layer.lpBypassFrequency, count: PadBank.padCount)
    var cachedHPCoeffs: [BiquadCoefficients] = Array(repeating: .bypass, count: PadBank.padCount)
    var cachedLPCoeffs: [BiquadCoefficients] = Array(repeating: .bypass, count: PadBank.padCount)

    // MARK: - UI sync throttle

    static let uiUpdateHz: Double = 33.0
    static let uiUpdateFrameThreshold = Int(Transport.sampleRate / uiUpdateHz)

    var pendingLevels: [Float] = Array(repeating: 0, count: PadBank.padCount)
    var pendingTriggers: [Bool] = Array(repeating: false, count: PadBank.padCount)
    var pendingHits: [(padIndex: Int, position: Int, velocity: Int)] = []
    var uiUpdateCounter = 0
    private var lastClearedLayerIndex: Int?
    private var preMuteMasterVolume: Float?

    // MARK: - Transport control

    func togglePlay() {
        transport.isPlaying.toggle()
        os_unfair_lock_lock(&audioLock)
        if !transport.isPlaying {
            transport.position = 0
            audio.position = 0
            audio.isPlaying = false
            voicePool.killAll()
        } else {
            audio.isPlaying = true
        }
        os_unfair_lock_unlock(&audioLock)

    }

    func stop() {
        transport.isPlaying = false
        transport.position = 0
        os_unfair_lock_lock(&audioLock)
        audio.position = 0
        audio.isPlaying = false
        voicePool.killAll()
        os_unfair_lock_unlock(&audioLock)

    }

    /// Whether any pad has recorded hits
    var hasRecordedHits: Bool {
        layers.contains { !$0.hits.isEmpty }
    }

    func setBPM(_ bpm: Int) {
        transport.bpm = bpm
        os_unfair_lock_lock(&audioLock)
        audio.bpm = transport.bpm
        os_unfair_lock_unlock(&audioLock)
    }

    func setBarCount(_ count: Int) {
        transport.barCount = count
        os_unfair_lock_lock(&audioLock)
        audio.barCount = transport.barCount
        os_unfair_lock_unlock(&audioLock)
    }

    func cycleBarCount(forward: Bool) {
        let options = [1, 2, 4]
        if let idx = options.firstIndex(of: transport.barCount) {
            let next = forward ? min(idx + 1, options.count - 1) : max(idx - 1, 0)
            setBarCount(options[next])
        }
    }

    // MARK: - Master volume

    func setMasterVolume(_ value: Float) {
        let clamped = max(0, min(1.0, value))
        audio.masterVolume = clamped
        DispatchQueue.main.async { [weak self] in
            self?.masterVolume = clamped
            self?.saveMasterVolume()
        }
    }

    var isMasterMuted: Bool { masterVolume == 0 && preMuteMasterVolume != nil }

    func toggleMasterMute() {
        if let saved = preMuteMasterVolume {
            // Restore
            preMuteMasterVolume = nil
            setMasterVolume(saved)
        } else {
            // Mute
            preMuteMasterVolume = masterVolume
            setMasterVolume(0)
        }
    }

    private static let masterVolumeURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".genesis")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("master.txt")
    }()

    static func loadMasterVolume() -> Float {
        guard let str = try? String(contentsOf: masterVolumeURL, encoding: .utf8),
              let val = Float(str.trimmingCharacters(in: .whitespacesAndNewlines)) else { return 1.0 }
        return max(0, min(1.0, val))
    }

    private func saveMasterVolume() {
        try? String(masterVolume).write(to: Self.masterVolumeURL, atomically: true, encoding: .utf8)
    }

    // MARK: - BPM detection

    func detectBPM(forPad index: Int) {
        guard let sample = padBank.pads[index].sample else {
            detectedBPMs[index] = nil
            return
        }
        detectedBPMs[index] = BPMDetector.extractFromName(sample.name)
    }

    // MARK: - Layer control

    func setLayerVolume(_ index: Int, volume: Float) {
        guard index >= 0, index < layers.count else { return }
        layers[index].volume = max(0, min(1.0, volume))
    }

    func setSwing(_ index: Int, swing: Float) {
        guard index >= 0, index < layers.count else { return }
        layers[index].swing = swing  // didSet clamps to 0.5–0.75
        os_unfair_lock_lock(&audioLock)
        audio.layers[index].swing = layers[index].swing
        os_unfair_lock_unlock(&audioLock)
    }

    var loopDurationMs: Double {
        Double(transport.loopLengthFrames) / Transport.sampleRate * 1000.0
    }

    func toggleMute(layer index: Int) {
        guard index >= 0, index < layers.count else { return }
        if toggleMode == .instant {
            layers[index].isMuted.toggle()
            os_unfair_lock_lock(&audioLock)
            audio.layers[index].isMuted = layers[index].isMuted
            os_unfair_lock_unlock(&audioLock)
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
        os_unfair_lock_lock(&audioLock)
        audio.toggleMode = toggleMode
        if toggleMode == .instant {
            for (index, muteState) in pendingMutes {
                layers[index].isMuted = muteState
                audio.layers[index].isMuted = muteState
            }
            pendingMutes.removeAll()
            audio.pendingMutes.removeAll()
        }
        os_unfair_lock_unlock(&audioLock)
    }

    func cycleVelocityMode() {
        velocityMode = velocityMode == .pressure ? .full : .pressure
    }

    // MARK: - Pad recording

    func togglePadRecording(_ index: Int) {
        guard index >= 0, index < layers.count else { return }
        layers[index].isRecording.toggle()
        os_unfair_lock_lock(&audioLock)
        audio.layers[index].isRecording = layers[index].isRecording
        os_unfair_lock_unlock(&audioLock)
    }

    func queuePad(_ index: Int) {
        guard index >= 0, index < layers.count else { return }
        layers[index].queued = true
        os_unfair_lock_lock(&audioLock)
        audio.layers[index].queued = true
        os_unfair_lock_unlock(&audioLock)
    }

    func muteAll() {
        os_unfair_lock_lock(&audioLock)
        for i in 0..<PadBank.padCount {
            layers[i].isMuted = true
            audio.layers[i].isMuted = true
        }
        voicePool.killAll()
        os_unfair_lock_unlock(&audioLock)
    }

    func toggleChoke(pad index: Int) {
        guard index >= 0, index < layers.count else { return }
        layers[index].choke.toggle()
        os_unfair_lock_lock(&audioLock)
        audio.layers[index].choke = layers[index].choke
        os_unfair_lock_unlock(&audioLock)
    }

    func toggleLooper(pad index: Int) {
        guard index >= 0, index < layers.count else { return }
        var layer = layers[index]
        layer.looper.toggle()
        layers[index] = layer
        os_unfair_lock_lock(&audioLock)
        audio.layers[index].looper = layer.looper
        os_unfair_lock_unlock(&audioLock)
    }

    func syncChokeToPadBank() {
        for i in 0..<PadBank.padCount {
            padBank.pads[i].choke = layers[i].choke
        }
    }

    func restoreChokeFromPadBank() {
        for i in 0..<PadBank.padCount {
            let choke = padBank.pads[i].choke
            layers[i].choke = choke
            audio.layers[i].choke = choke
        }
    }

    func clearLayer(_ index: Int) {
        guard index >= 0, index < layers.count else { return }
        layers[index].clear()
        os_unfair_lock_lock(&audioLock)
        audio.layers[index].clear()
        voicePool.killPad(index)
        os_unfair_lock_unlock(&audioLock)
        lastClearedLayerIndex = index

    }

    func undoLastClear() {
        guard let index = lastClearedLayerIndex else { return }
        layers[index].undo()
        os_unfair_lock_lock(&audioLock)
        audio.layers[index].undo()
        os_unfair_lock_unlock(&audioLock)
        lastClearedLayerIndex = nil

    }

    // MARK: - Trigger roll editing

    func addHitToLayer(_ padIndex: Int, at position: Int, velocity: Int) {
        guard padIndex >= 0, padIndex < layers.count else { return }
        layers[padIndex].addHit(at: position, velocity: velocity)
        layers[padIndex].name = padBank.pads[padIndex].name
        os_unfair_lock_lock(&audioLock)
        audio.layers[padIndex].addHit(at: position, velocity: velocity)
        audio.layers[padIndex].name = padBank.pads[padIndex].name
        os_unfair_lock_unlock(&audioLock)
    }

    func removeHitFromLayer(_ padIndex: Int, near position: Int, tolerance: Int) {
        guard padIndex >= 0, padIndex < layers.count else { return }
        if let idx = layers[padIndex].hits.firstIndex(where: { abs($0.position - position) < tolerance }) {
            layers[padIndex].hits.remove(at: idx)
            os_unfair_lock_lock(&audioLock)
            if let audioIdx = audio.layers[padIndex].hits.firstIndex(where: { abs($0.position - position) < tolerance }) {
                audio.layers[padIndex].hits.remove(at: audioIdx)
            }
            os_unfair_lock_unlock(&audioLock)
        }
    }

    // MARK: - Capture

    func toggleCapture() {
        let wasOff = capture.state == .off
        capture.toggle()
        os_unfair_lock_lock(&audioLock)
        audio.captureState = capture.state
        audio.capture = capture
        // Cut all ringing voices when looper starts so trailing notes don't bleed in
        if wasOff && capture.state == .on {
            voicePool.killAll()
        }
        os_unfair_lock_unlock(&audioLock)
    }

    func toggleMetronome() {
        metronome.isOn.toggle()
        os_unfair_lock_lock(&audioLock)
        audio.metronomeOn = metronome.isOn
        os_unfair_lock_unlock(&audioLock)
    }


    // MARK: - Centralized sample loading (single source of truth)

    func loadSample(from url: URL, forPad index: Int) throws {
        let sample = try Sample.load(from: url)
        padBank.assign(sample: sample, toPad: index)
        padBank.pads[index].samplePath = url.path
        layers[index].name = sample.name.uppercased()
        syncChokeToPadBank()
        do {
            try padBank.save()
        } catch {
            // Non-fatal: config save failure doesn't affect playback
        }
        detectBPM(forPad: index)
    }
}

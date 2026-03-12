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
    var masterVolume: Float = 1.0

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
    @Published var masterVolume: Float = GodEngine.loadMasterVolume()
    @Published var detectedBPMs: [Int: Double] = [:]
    @Published var activePadIndex: Int = 0 {
        didSet { audio.activePadIndex = activePadIndex }
    }
    @Published var toggleMode: ToggleMode = .instant
    @Published var velocityMode: VelocityMode = .pressure
    @Published var pendingMutes: [Int: Bool] = [:]  // pad index -> target mute state
    var interpreter: EngineEventInterpreter?

    // MARK: - Audio thread state (never touch @Published from here)

    var audio = AudioState(masterVolume: GodEngine.loadMasterVolume())
    var voices: [Voice] = []
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

    // MARK: - Transport control

    func togglePlay() {
        transport.isPlaying.toggle()
        os_unfair_lock_lock(&audioLock)
        if !transport.isPlaying {
            transport.position = 0
            audio.position = 0
            audio.isPlaying = false
            voices.removeAll()
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
        voices.removeAll()
        os_unfair_lock_unlock(&audioLock)
    }

    func killAllVoices() {
        os_unfair_lock_lock(&audioLock)
        voices.removeAll()
        os_unfair_lock_unlock(&audioLock)
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

    // MARK: - Master volume

    func setMasterVolume(_ value: Float) {
        let clamped = max(0, min(1.0, value))
        audio.masterVolume = clamped
        DispatchQueue.main.async { [weak self] in
            self?.masterVolume = clamped
            self?.saveMasterVolume()
        }
    }

    private static let masterVolumeURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".god")
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

    // MARK: - Layer control

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
            os_unfair_lock_lock(&audioLock)
            audio.layers[index].isMuted = layers[index].isMuted
            if layers[index].isMuted {
                voices.removeAll { $0.padIndex == index }
            }
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

    func toggleTcps(pad index: Int) {
        guard index >= 0, index < layers.count else { return }
        layers[index].tcps.toggle()
        audio.layers[index].tcps = layers[index].tcps
    }

    func syncTcpsToPadBank() {
        for i in 0..<PadBank.padCount {
            padBank.pads[i].tcps = layers[i].tcps
        }
    }

    func restoreTcpsFromPadBank() {
        for i in 0..<PadBank.padCount {
            let tcps = padBank.pads[i].tcps
            layers[i].tcps = tcps
            audio.layers[i].tcps = tcps
        }
    }

    func clearLayer(_ index: Int) {
        guard index >= 0, index < layers.count else { return }
        layers[index].clear()
        os_unfair_lock_lock(&audioLock)
        audio.layers[index].clear()
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

    // MARK: - Capture

    func toggleCapture() {
        capture.toggle()
        os_unfair_lock_lock(&audioLock)
        audio.captureState = capture.state
        audio.capture = capture
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
        syncTcpsToPadBank()
        do {
            try padBank.save()
        } catch {
            // Non-fatal: config save failure doesn't affect playback
        }
        detectBPM(forPad: index)
    }
}

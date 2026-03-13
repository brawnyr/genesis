// Genesis/Genesis/Engine/GenesisEngine+ProcessBlock.swift
import Foundation

/// Lightweight snapshot of audio state for UI sync — avoids .map {} heap allocations on audio thread.
private struct UISnapshot {
    var pos: Int = 0
    var levels: [Float] = Array(repeating: 0, count: PadBank.padCount)
    var masterPeak: Float = 0
    var triggers: [Bool] = Array(repeating: false, count: PadBank.padCount)
    var activeIdx: Int = 0
    var hits: [(padIndex: Int, position: Int, velocity: Int)] = []
    var activeVoicePads: Set<Int> = []
    var layerVolumes = Array(repeating: Float(1.0), count: PadBank.padCount)
    var layerPans = Array(repeating: Float(0.5), count: PadBank.padCount)
    var layerHPCutoffs = Array(repeating: Layer.hpBypassFrequency, count: PadBank.padCount)
    var layerLPCutoffs = Array(repeating: Layer.lpBypassFrequency, count: PadBank.padCount)
    var layerSwings = Array(repeating: Float(0.5), count: PadBank.padCount)
    var layerIsRecording = Array(repeating: false, count: PadBank.padCount)
    var layerHasNewHits = Array(repeating: false, count: PadBank.padCount)
}

extension GenesisEngine {
    /// Convenience for tests — processes a block and returns stereo arrays.
    func processBlock(frameCount: Int) -> (left: [Float], right: [Float]) {
        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)
        left.withUnsafeMutableBufferPointer { leftBuf in
            right.withUnsafeMutableBufferPointer { rightBuf in
                processBlock(frameCount: frameCount, intoLeft: leftBuf.baseAddress, intoRight: rightBuf.baseAddress)
            }
        }
        return (left, right)
    }

    // MARK: - Pad hit handling (audio thread)

    func handlePadHit(note: Int, velocity: Int, record: Bool) {
        guard let padIndex = padBank.padIndex(forNote: note),
              let sample = padBank.pads[padIndex].sample else { return }
        guard !audio.layers[padIndex].isMuted else { return }

        audio.activePadIndex = padIndex

        // Record hits whenever the loop is playing — all pads always armed
        if record && audio.isPlaying {
            audio.layers[padIndex].addHit(at: audio.position, velocity: velocity)
            audio.layers[padIndex].name = padBank.pads[padIndex].name
            audio.layers[padIndex].hasNewHits = true
        }

        if audio.layers[padIndex].choke {
            voicePool.killPad(padIndex)
        }
        let vel = velocityMode == .full ? Float(1.0) : Float(velocity) / 127.0
        if let idx = voicePool.allocate(sample: sample, velocity: vel, padIndex: padIndex) {
            _ = idx // allocation is the side effect
        }

        let reportedVel = velocityMode == .full ? 127 : velocity
        pendingHits.append((padIndex: padIndex, position: audio.position, velocity: reportedVel))
        pendingTriggers[padIndex] = true
    }

    func handleNoteOff(note: Int) {
        guard let padIndex = padBank.padIndex(forNote: note) else { return }
        guard !padBank.pads[padIndex].isOneShot else { return }
        voicePool.killPad(padIndex)
    }

    func handleCC(number: Int, value: Int) {
        switch number {
        case 82: // Master volume (MiniLab fader 1) — 0 to +6dB
            setMasterVolume(Float(value) / 127.0 * 2.0)
        case 74: // Pad volume (knob 1) — 0 to +6dB
            audio.layers[audio.activePadIndex].volume = Float(value) / 127.0 * 2.0
        case 71: // Pan (knob 2)
            audio.layers[audio.activePadIndex].pan = Float(value) / 127.0
        case 76: // HP cutoff (knob 3)
            audio.layers[audio.activePadIndex].hpCutoff = ccToFrequency(value)
        case 77: // LP cutoff (knob 4)
            audio.layers[audio.activePadIndex].lpCutoff = ccToFrequency(value)
        case 114: // Browse encoder — pad select (relative: 1=CW, 127=CCW, 64=neutral)
            if value >= 1 && value <= 63 {
                audio.activePadIndex = min(audio.activePadIndex + 1, PadBank.padCount - 1)
            } else if value >= 65 && value <= 127 {
                audio.activePadIndex = max(audio.activePadIndex - 1, 0)
            }
        case 18: // Swing (knob 5)
            audio.layers[audio.activePadIndex].swing = 0.5 + (Float(value) / 127.0) * 0.25
        default:
            DispatchQueue.main.async { [weak self] in
                self?.interpreter?.appendLine("CC \(number) = \(value)", kind: .system)
            }
        }
    }

    func updateCachedCoefficients() {
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

    // MARK: - Audio render callback

    func processBlock(frameCount: Int, intoLeft destL: UnsafeMutablePointer<Float>?, intoRight destR: UnsafeMutablePointer<Float>?) {
        os_unfair_lock_lock(&audioLock)
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
        var wrapFrame = frameCount  // frame index within block where loop wraps
        if audio.isPlaying, loopLen > 0 {
            let startPos = audio.position

            // Check each layer for hits in this block's range (before draining MIDI,
            // so live hits recorded this block don't retrigger via the loop path)
            for layerIdx in 0..<audio.layers.count {
                let layer = audio.layers[layerIdx]
                guard !layer.isMuted, !layer.hits.isEmpty else { continue }

                let beatsPerLoop = audio.barCount * Transport.beatsPerBar
                let sixteenthLen = SwingMath.sixteenthLength(loopLengthFrames: loopLen, beatsPerLoop: beatsPerLoop)
                let maxOffset = SwingMath.maxSwingOffset(sixteenthLength: sixteenthLen)
                let endPos = startPos + frameCount

                // Expand scan range backward to catch hits swung into this block
                let scanStart = startPos - maxOffset
                let scanEnd = endPos

                let hits: [Hit]
                if scanStart < 0 {
                    // Scan wraps backward past loop start
                    let beforeWrap = layer.hits(inRange: (loopLen + scanStart)..<loopLen)
                    let mainRange = layer.hits(inRange: 0..<min(scanEnd, loopLen))
                    hits = beforeWrap + mainRange
                } else if scanEnd <= loopLen {
                    hits = layer.hits(inRange: scanStart..<scanEnd)
                } else {
                    let beforeWrap = layer.hits(inRange: scanStart..<loopLen)
                    let afterWrap = layer.hits(inRange: 0..<(scanEnd - loopLen))
                    hits = beforeWrap + afterWrap
                }

                for hit in hits {
                    let swungFrame = SwingMath.swungPosition(
                        hitFrame: hit.position,
                        swing: layer.swing,
                        sixteenthLength: sixteenthLen,
                        loopLength: loopLen
                    )

                    // Check if swung position falls within this block
                    let inBlock: Bool
                    if endPos <= loopLen {
                        inBlock = swungFrame >= startPos && swungFrame < endPos
                    } else {
                        // Block wraps around loop boundary
                        inBlock = swungFrame >= startPos || swungFrame < (endPos - loopLen)
                    }
                    guard inBlock else { continue }

                    if let sample = padBank.pads[layer.index].sample {
                        voicePool.killPad(layer.index)
                        let vel = velocityMode == .full ? Float(1.0) : Float(hit.velocity) / 127.0
                        var offset = swungFrame - startPos
                        if offset < 0 { offset += loopLen }
                        if let idx = voicePool.allocate(sample: sample, velocity: vel, padIndex: layer.index) {
                            voicePool.slots[idx].blockOffset = max(0, min(offset, frameCount - 1))
                        }
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

            // Metronome — sample-accurate click placement
            if audio.metronomeOn {
                let beatLen = Metronome.beatLengthFramesStatic(bpm: audio.bpm, sampleRate: Transport.sampleRate)
                for i in 0..<frameCount {
                    let frameInLoop = (startPos + i) % loopLen
                    if beatLen > 0 && frameInLoop % beatLen == 0 {
                        let beatIndex = frameInLoop / beatLen % 4
                        let click = Metronome.click(beatIndex: beatIndex)
                        if let idx = voicePool.allocate(sample: click, velocity: audio.metronomeVolume, padIndex: -1) {
                            voicePool.slots[idx].blockOffset = i
                        }
                    }
                }
            }

            // Advance audio position
            audio.position += frameCount
            if audio.position >= loopLen {
                wrapFrame = frameCount - (audio.position - loopLen)
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
        let frameLevels = VoiceMixer.mix(
            pool: &voicePool,
            layers: audio.layers,
            cachedHP: cachedHPCoeffs,
            cachedLP: cachedLPCoeffs,
            intoLeft: &outputBufferL,
            intoRight: &outputBufferR,
            count: frameCount
        )
        for i in 0..<PadBank.padCount {
            pendingLevels[i] = max(pendingLevels[i], frameLevels[i])
        }

        // Apply master volume
        for i in 0..<frameCount {
            outputBufferL[i] *= audio.masterVolume
            outputBufferR[i] *= audio.masterVolume
        }

        // Brickwall peak limiter — instant attack, smooth release, ceiling at -1 dBTP
        let peak = limiter.process(left: &outputBufferL, right: &outputBufferR, count: frameCount)

        // Declick: apply short crossfade at loop boundary to eliminate pops
        if wrapped {
            let declickFrames = 88  // ~2ms at 44.1kHz
            let fadeSamples = max(0, min(declickFrames, wrapFrame, frameCount - wrapFrame))
            // Fade out leading into wrap point
            for i in 0..<fadeSamples {
                let gain = Float(i) / Float(fadeSamples)  // 0→1 going backward from wrap
                let idx = wrapFrame - fadeSamples + i
                if idx >= 0 {
                    outputBufferL[idx] *= gain
                    outputBufferR[idx] *= gain
                }
            }
            // Fade in after wrap point
            for i in 0..<fadeSamples {
                let gain = Float(i) / Float(fadeSamples)  // 0→1
                let idx = wrapFrame + i
                if idx < frameCount {
                    outputBufferL[idx] *= gain
                    outputBufferR[idx] *= gain
                }
            }
        }

        // Snapshot capture state — actual append happens after lock release
        let shouldCapture = audio.captureState == .on

        // Collect data for deferred main-thread work (outside lock)
        var appliedMutes: [Int: Bool]? = nil
        var appliedVolumes: [Int: Float]? = nil
        var appliedLoopers: [Int: Bool]? = nil

        if wrapped {
            // Apply pending changes BEFORE voice allocation so new state takes effect this loop
            if !audio.pendingMutes.isEmpty {
                appliedMutes = audio.pendingMutes
                for (index, muteState) in audio.pendingMutes {
                    audio.layers[index].isMuted = muteState
                }
                audio.pendingMutes.removeAll()
            }
            if !audio.pendingVolumes.isEmpty {
                appliedVolumes = audio.pendingVolumes
                for (index, vol) in audio.pendingVolumes {
                    audio.layers[index].volume = vol
                }
                audio.pendingVolumes.removeAll()
            }
            if !audio.pendingLoopers.isEmpty {
                appliedLoopers = audio.pendingLoopers
                for (index, looper) in audio.pendingLoopers {
                    audio.layers[index].looper = looper
                }
                audio.pendingLoopers.removeAll()
            }

            // Kill pad voices at loop boundary — let metronome clicks ring out
            voicePool.killPads()

            // Handle queued pads — fire at beat 1 of new loop
            for i in 0..<PadBank.padCount {
                if audio.layers[i].queued {
                    audio.layers[i].queued = false
                    if let sample = padBank.pads[i].sample, !audio.layers[i].isMuted {
                        let vel: Float = velocityMode == .full ? 1.0 : 0.8
                        let _ = voicePool.allocate(sample: sample, velocity: vel, padIndex: i)
                    }
                }
            }

            // Looper pads — retrigger sample on beat 1 every loop
            for i in 0..<PadBank.padCount {
                if audio.layers[i].looper, !audio.layers[i].isMuted,
                   let sample = padBank.pads[i].sample {
                    voicePool.killPad(i)
                    let vel: Float = velocityMode == .full ? 1.0 : audio.layers[i].volume
                    let _ = voicePool.allocate(sample: sample, velocity: vel, padIndex: i)
                }
            }
        }

        // Throttle UI updates — sync position + levels ~30x/sec
        var uiSnapshot: UISnapshot? = nil
        uiUpdateCounter += frameCount
        if uiUpdateCounter >= Self.uiUpdateFrameThreshold {
            uiUpdateCounter = 0

            // Snapshot audio state into stack-allocated fixed arrays (no heap allocs)
            var snap = UISnapshot()
            snap.pos = audio.position
            snap.levels = pendingLevels
            snap.masterPeak = peak
            snap.triggers = pendingTriggers
            snap.activeIdx = audio.activePadIndex
            snap.hits = pendingHits
            for i in 0..<PadBank.padCount {
                snap.layerVolumes[i] = audio.layers[i].volume
                snap.layerPans[i] = audio.layers[i].pan
                snap.layerHPCutoffs[i] = audio.layers[i].hpCutoff
                snap.layerLPCutoffs[i] = audio.layers[i].lpCutoff
                snap.layerSwings[i] = audio.layers[i].swing
                snap.layerIsRecording[i] = audio.layers[i].isRecording
                snap.layerHasNewHits[i] = audio.layers[i].hasNewHits
                if voicePool.hasPadVoice(i) {
                    snap.activeVoicePads.insert(i)
                }
            }

            pendingHits.removeAll(keepingCapacity: true)
            pendingLevels = Array(repeating: 0, count: PadBank.padCount)
            pendingTriggers = Array(repeating: false, count: PadBank.padCount)
            uiSnapshot = snap
        }

        // Copy into destination audio buffers
        if let destL = destL, let destR = destR {
            for i in 0..<frameCount {
                destL[i] = outputBufferL[i]
                destR[i] = outputBufferR[i]
            }
        }
        os_unfair_lock_unlock(&audioLock)

        // === Everything below runs OUTSIDE the audio lock ===

        // Capture — avoids heap allocations while holding spinlock
        if shouldCapture {
            outputBufferL.withUnsafeBufferPointer { leftPtr in
                outputBufferR.withUnsafeBufferPointer { rightPtr in
                    let leftSlice = UnsafeBufferPointer(rebasing: leftPtr[0..<frameCount])
                    let rightSlice = UnsafeBufferPointer(rebasing: rightPtr[0..<frameCount])
                    audio.capture.appendFromBuffers(left: leftSlice, right: rightSlice)
                }
            }
        }

        // Dispatch main-thread UI sync (outside lock to avoid priority inversion)
        if wrapped {
            if appliedMutes != nil || appliedVolumes != nil || appliedLoopers != nil {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if let mutes = appliedMutes {
                        for (index, muteState) in mutes {
                            self.layers[index].isMuted = muteState
                        }
                        self.pendingMutes.removeAll()
                    }
                    if let volumes = appliedVolumes {
                        for (index, vol) in volumes {
                            self.layers[index].volume = vol
                        }
                        self.pendingVolumes.removeAll()
                    }
                    if let loopers = appliedLoopers {
                        for (index, looper) in loopers {
                            self.layers[index].looper = looper
                        }
                        self.pendingLoopers.removeAll()
                    }
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                for i in 0..<PadBank.padCount {
                    self.layers[i].queued = false
                }
                self.interpreter?.onLoopBoundary(
                    layers: self.layers,
                    padBank: self.padBank,
                    loopDurationMs: self.loopDurationMs,
                    transport: self.transport
                )
            }
        }

        if let snap = uiSnapshot {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.activePadIndex = snap.activeIdx

                if self.transport.isPlaying && !snap.hits.isEmpty {
                    for hit in snap.hits {
                        self.layers[hit.padIndex].addHit(at: hit.position, velocity: hit.velocity)
                        self.layers[hit.padIndex].name = self.padBank.pads[hit.padIndex].name
                    }
                }
                self.transport.position = snap.pos
                self.channelSignalLevels = snap.levels
                self.masterLevel = snap.masterPeak
                self.masterLevelDb = linearToDb(snap.masterPeak)
                self.channelLevelDb = snap.levels.map { linearToDb($0) }
                for i in 0..<PadBank.padCount {
                    if snap.triggers[i] {
                        self.channelTriggered[i] = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                            self?.channelTriggered[i] = false
                        }
                    }
                    self.layers[i].volume = snap.layerVolumes[i]
                    self.layers[i].pan = snap.layerPans[i]
                    self.layers[i].hpCutoff = snap.layerHPCutoffs[i]
                    self.layers[i].lpCutoff = snap.layerLPCutoffs[i]
                    self.layers[i].swing = snap.layerSwings[i]
                    self.layers[i].isRecording = snap.layerIsRecording[i]
                    self.layers[i].hasNewHits = snap.layerHasNewHits[i]
                }
                if let interp = self.interpreter {
                    interp.activePadVoices = snap.activeVoicePads
                    interp.processHits(snap.hits, padBank: self.padBank, loopDurationMs: self.loopDurationMs)
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
    }
}

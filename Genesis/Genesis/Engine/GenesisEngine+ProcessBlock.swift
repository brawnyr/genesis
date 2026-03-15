// Genesis/Genesis/Engine/GenesisEngine+ProcessBlock.swift
import Foundation

/// Lightweight snapshot of audio state for UI sync.
/// Pre-allocated as a persistent member of GenesisEngine and reused each cycle
/// to avoid repeated heap allocations on the audio thread.
struct UISnapshot {
    var pos: Int = 0
    var levels: [Float] = Array(repeating: 0, count: PadBank.padCount)
    var masterPeak: Float = 0
    var triggers: [Bool] = Array(repeating: false, count: PadBank.padCount)
    var activeIdx: Int = 0
    var hits: [(padIndex: Int, position: Int, velocity: Int)] = []
    var replayHits: [(padIndex: Int, position: Int, velocity: Int)] = []
    var activeVoicePads: Set<Int> = []
    var layerVolumes = Array(repeating: Float(1.0), count: PadBank.padCount)
    var layerPans = Array(repeating: Float(0.5), count: PadBank.padCount)
    var layerHPCutoffs = Array(repeating: Layer.hpBypassFrequency, count: PadBank.padCount)
    var layerLPCutoffs = Array(repeating: Layer.lpBypassFrequency, count: PadBank.padCount)
    var layerSwings = Array(repeating: Float(0.5), count: PadBank.padCount)
    var layerReverbSends = Array(repeating: Float(0.0), count: PadBank.padCount)
    var layerIsRecording = Array(repeating: false, count: PadBank.padCount)
    var layerHasNewHits = Array(repeating: false, count: PadBank.padCount)
    var valid: Bool = false
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

        // Record hits when playing AND recording is armed
        if record && audio.isPlaying && audio.isRecording {
            audio.layers[padIndex].addHit(at: audio.position, velocity: velocity)
            audio.layers[padIndex].name = padBank.pads[padIndex].name
            audio.layers[padIndex].hasNewHits = true
        }

        if audio.layers[padIndex].choke {
            voicePool.killPad(padIndex)
        }
        let vel = audio.velocityMode == .full ? Float(1.0) : Float(velocity) / 127.0
        let pan = audio.layers[padIndex].pan
        if let idx = voicePool.allocate(sample: sample, velocity: vel, padIndex: padIndex, pan: pan) {
            _ = idx // allocation is the side effect
        }

        let reportedVel = audio.velocityMode == .full ? 127 : velocity
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
        case 82: // Master volume (MiniLab fader 1)
            setMasterVolume(Float(value) / 127.0)
        case 74: // Reverb send (knob 1)
            audio.layers[audio.activePadIndex].reverbSend = Float(value) / 127.0
        case 83: // Pad volume (MiniLab fader 2)
            audio.layers[audio.activePadIndex].volume = Float(value) / 127.0
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
        case 85: // Metronome volume (CC 85)
            audio.metronomeVolume = Float(value) / 127.0
        case 18: // Swing (knob 5)
            audio.layers[audio.activePadIndex].swing = 0.5 + (Float(value) / 127.0) * 0.5
        case 17: // Fader 4 — kill all voices
            voicePool.killAll()
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

    // MARK: - Replay hit processing (no allocations)

    private func processReplayHit(_ hit: Hit, layer: Layer, layerSwing: Float,
                                   sixteenthLen: Int, loopLen: Int,
                                   startPos: Int, endPos: Int, frameCount: Int) {
        let swungFrame = SwingMath.swungPosition(
            hitFrame: hit.position, swing: layerSwing,
            sixteenthLength: sixteenthLen, loopLength: loopLen
        )

        let inBlock: Bool
        if endPos <= loopLen {
            inBlock = swungFrame >= startPos && swungFrame < endPos
        } else {
            inBlock = swungFrame >= startPos || swungFrame < (endPos - loopLen)
        }
        guard inBlock else { return }

        if let sample = padBank.pads[layer.index].sample {
            voicePool.killPad(layer.index)
            let vel = audio.velocityMode == .full ? Float(1.0) : Float(hit.velocity) / 127.0
            var offset = swungFrame - startPos
            if offset < 0 { offset += loopLen }
            if let idx = voicePool.allocate(sample: sample, velocity: vel, padIndex: layer.index, pan: layer.pan) {
                voicePool.slots[idx].blockOffset = max(0, min(offset, frameCount - 1))
            }
            pendingReplayHits.append((padIndex: layer.index, position: hit.position, velocity: hit.velocity))
        }
    }

    // MARK: - Audio render callback

    func processBlock(frameCount: Int, intoLeft destL: UnsafeMutablePointer<Float>?, intoRight destR: UnsafeMutablePointer<Float>?) {
        // === LOCK SECTION 1: Read audio state, scan hits, drain MIDI, advance position ===
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
        let masterVol = audio.masterVolume
        let shouldCapture = audio.captureState == .on

        // Loop replay, metronome, and position advance only when playing
        var wrapped = false
        var wrapFrame = frameCount  // frame index within block where loop wraps
        if audio.isPlaying, loopLen > 0 {
            let startPos = audio.position

            // Check each layer for hits in this block's range (before draining MIDI,
            // so live hits recorded this block don't retrigger via the loop path).
            // Scans in-place — no array allocations on the audio thread.
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

                // Iterate directly over the layer's hit array — no intermediate allocations.
                // We scan two ranges when the window wraps around the loop boundary.
                let allHits = layer.hits
                let hitCount = allHits.count
                guard hitCount > 0 else { continue }

                // Scan range 1
                let r1Start: Int
                let r1End: Int
                // Scan range 2 (used when scan window wraps)
                var r2Start: Int = 0
                var r2End: Int = 0

                if scanStart < 0 {
                    r1Start = loopLen + scanStart
                    r1End = loopLen
                    r2Start = 0
                    r2End = min(scanEnd, loopLen)
                } else if scanEnd <= loopLen {
                    r1Start = scanStart
                    r1End = scanEnd
                } else {
                    r1Start = scanStart
                    r1End = loopLen
                    r2Start = 0
                    r2End = scanEnd - loopLen
                }

                // Binary search for start of range 1
                var lo = 0; var hi = hitCount
                while lo < hi {
                    let mid = (lo + hi) / 2
                    if allHits[mid].position < r1Start { lo = mid + 1 } else { hi = mid }
                }

                // Process range 1
                var idx = lo
                while idx < hitCount && allHits[idx].position < r1End {
                    processReplayHit(allHits[idx], layer: layer, layerSwing: layer.swing,
                                     sixteenthLen: sixteenthLen, loopLen: loopLen,
                                     startPos: startPos, endPos: endPos, frameCount: frameCount)
                    idx += 1
                }

                // Process range 2 (if scan wraps)
                if r2End > r2Start {
                    lo = 0; hi = hitCount
                    while lo < hi {
                        let mid = (lo + hi) / 2
                        if allHits[mid].position < r2Start { lo = mid + 1 } else { hi = mid }
                    }
                    idx = lo
                    while idx < hitCount && allHits[idx].position < r2End {
                        processReplayHit(allHits[idx], layer: layer, layerSwing: layer.swing,
                                         sixteenthLen: sixteenthLen, loopLen: loopLen,
                                         startPos: startPos, endPos: endPos, frameCount: frameCount)
                        idx += 1
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

                // Looper pads — trigger sample at exact wrap point (beat 1)
                for i in 0..<PadBank.padCount {
                    if audio.layers[i].looper, !audio.layers[i].isMuted,
                       let sample = padBank.pads[i].sample {
                        voicePool.killPad(i)
                        let vel: Float = audio.velocityMode == .full ? 1.0 : audio.layers[i].volume
                        if let idx = voicePool.allocate(sample: sample, velocity: vel, padIndex: i, pan: audio.layers[i].pan) {
                            voicePool.slots[idx].blockOffset = max(0, min(wrapFrame, frameCount - 1))
                        }
                    }
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

        // Update cached biquad coefficients (only recalculates when cutoffs change)
        updateCachedCoefficients()

        // Snapshot layer rendering params while locked (cheap scalar copies)
        // These local copies let us release the lock before the heavy render pass
        var localLayerVolumes = (Float(0), Float(0), Float(0), Float(0), Float(0), Float(0), Float(0), Float(0))
        var localLayerPans = (Float(0), Float(0), Float(0), Float(0), Float(0), Float(0), Float(0), Float(0))
        var localLayerReverbSends = (Float(0), Float(0), Float(0), Float(0), Float(0), Float(0), Float(0), Float(0))
        withUnsafeMutablePointer(to: &localLayerVolumes) { vPtr in
            vPtr.withMemoryRebound(to: Float.self, capacity: PadBank.padCount) { v in
                withUnsafeMutablePointer(to: &localLayerPans) { pPtr in
                    pPtr.withMemoryRebound(to: Float.self, capacity: PadBank.padCount) { p in
                        withUnsafeMutablePointer(to: &localLayerReverbSends) { rPtr in
                            rPtr.withMemoryRebound(to: Float.self, capacity: PadBank.padCount) { r in
                                for i in 0..<PadBank.padCount {
                                    v[i] = audio.layers[i].volume
                                    p[i] = audio.layers[i].pan
                                    r[i] = audio.layers[i].reverbSend
                                }
                            }
                        }
                    }
                }
            }
        }

        os_unfair_lock_unlock(&audioLock)

        // === UNLOCKED SECTION: Heavy rendering (voice mix, reverb, declick, master vol) ===
        // voicePool, outputBuffers, reverbSend, scratch — all audio-thread-only, no lock needed

        // Zero reverb send buffers and ensure scratch buffers are sized
        if reverbSendL.count < frameCount {
            reverbSendL = [Float](repeating: 0, count: frameCount)
            reverbSendR = [Float](repeating: 0, count: frameCount)
        } else {
            for i in 0..<frameCount {
                reverbSendL[i] = 0
                reverbSendR[i] = 0
            }
        }
        if voiceScratchL.count < frameCount {
            voiceScratchL = [Float](repeating: 0, count: frameCount)
            voiceScratchR = [Float](repeating: 0, count: frameCount)
        }

        // Mix all active voices — always, even when stopped (for pad auditioning)
        let frameLevels = VoiceMixer.mix(
            pool: &voicePool,
            layers: audio.layers,
            cachedHP: cachedHPCoeffs,
            cachedLP: cachedLPCoeffs,
            intoLeft: &outputBufferL,
            intoRight: &outputBufferR,
            reverbSendL: &reverbSendL,
            reverbSendR: &reverbSendR,
            scratchL: &voiceScratchL,
            scratchR: &voiceScratchR,
            count: frameCount
        )
        for i in 0..<PadBank.padCount {
            pendingLevels[i] = max(pendingLevels[i], frameLevels[i])
        }

        // Process reverb — its own bus, tail rings out naturally
        reverbSendL.withUnsafeBufferPointer { sendLPtr in
            reverbSendR.withUnsafeBufferPointer { sendRPtr in
                reverb.process(
                    sendL: sendLPtr.baseAddress!,
                    sendR: sendRPtr.baseAddress!,
                    intoLeft: &outputBufferL,
                    intoRight: &outputBufferR,
                    count: frameCount
                )
            }
        }

        // Apply master volume and track peak
        var peak: Float = 0
        for i in 0..<frameCount {
            outputBufferL[i] *= masterVol
            outputBufferR[i] *= masterVol
            peak = max(peak, abs(outputBufferL[i]), abs(outputBufferR[i]))
        }

        // MPC-style: voices ring through loop boundary naturally.
        // Per-voice declick handles choke/retrigger pops.
        // No output buffer crossfade, no blanket voice kill at wrap.

        // Copy into destination audio buffers
        if let destL = destL, let destR = destR {
            for i in 0..<frameCount {
                destL[i] = outputBufferL[i]
                destR[i] = outputBufferR[i]
            }
        }

        // === LOCK SECTION 2: Brief re-lock for UI snapshot (reads audio.position etc.) ===
        os_unfair_lock_lock(&audioLock)

        uiUpdateCounter += frameCount
        reusableSnapshot.valid = false
        if uiUpdateCounter >= Self.uiUpdateFrameThreshold {
            uiUpdateCounter = 0

            // Reuse pre-allocated snapshot — swap arrays instead of copying to avoid CoW allocs
            reusableSnapshot.pos = audio.position
            reusableSnapshot.masterPeak = peak
            reusableSnapshot.activeIdx = audio.activePadIndex

            // Swap levels/triggers (reusable gets current data, pending gets the old zeroed arrays back)
            swap(&reusableSnapshot.levels, &pendingLevels)
            swap(&reusableSnapshot.triggers, &pendingTriggers)

            // Swap hit arrays — snapshot takes accumulated hits, pending gets snapshot's old (empty) arrays
            swap(&reusableSnapshot.hits, &pendingHits)
            swap(&reusableSnapshot.replayHits, &pendingReplayHits)

            // Zero the pending arrays for next cycle
            for i in 0..<PadBank.padCount {
                pendingLevels[i] = 0
                pendingTriggers[i] = false
            }

            reusableSnapshot.activeVoicePads.removeAll(keepingCapacity: true)
            for i in 0..<PadBank.padCount {
                reusableSnapshot.layerVolumes[i] = audio.layers[i].volume
                reusableSnapshot.layerPans[i] = audio.layers[i].pan
                reusableSnapshot.layerHPCutoffs[i] = audio.layers[i].hpCutoff
                reusableSnapshot.layerLPCutoffs[i] = audio.layers[i].lpCutoff
                reusableSnapshot.layerSwings[i] = audio.layers[i].swing
                reusableSnapshot.layerReverbSends[i] = audio.layers[i].reverbSend
                reusableSnapshot.layerIsRecording[i] = audio.layers[i].isRecording
                reusableSnapshot.layerHasNewHits[i] = audio.layers[i].hasNewHits
                if voicePool.hasPadVoice(i) {
                    reusableSnapshot.activeVoicePads.insert(i)
                }
            }
            reusableSnapshot.valid = true
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
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.interpreter?.onLoopBoundary(
                    layers: self.layers,
                    padBank: self.padBank,
                    loopDurationMs: self.loopDurationMs,
                    transport: self.transport
                )
            }
        }

        if reusableSnapshot.valid {
            // Copy snapshot for dispatch — the reusable one stays owned by the engine
            let snap = reusableSnapshot
            reusableSnapshot.hits.removeAll(keepingCapacity: true)
            reusableSnapshot.replayHits.removeAll(keepingCapacity: true)

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
                    self.layers[i].reverbSend = snap.layerReverbSends[i]
                    self.layers[i].isRecording = snap.layerIsRecording[i]
                    self.layers[i].hasNewHits = snap.layerHasNewHits[i]
                }
                if let interp = self.interpreter {
                    interp.activePadVoices = snap.activeVoicePads
                    let allHits = snap.hits + snap.replayHits
                    interp.processHits(allHits, padBank: self.padBank, loopDurationMs: self.loopDurationMs,
                                       loopLengthFrames: self.transport.loopLengthFrames, barCount: self.transport.barCount)
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

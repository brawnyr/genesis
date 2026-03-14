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
        case 82: // Master volume (MiniLab fader 1)
            setMasterVolume(Float(value) / 127.0)
        case 74: // Reverb send (knob 1)
            audio.layers[audio.activePadIndex].reverbSend = Float(value) / 127.0
        case 85: // Pad volume (CC 85)
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
        case 83: // Metronome volume (MiniLab fader 2)
            audio.metronomeVolume = Float(value) / 127.0
        case 18: // Swing (knob 5)
            audio.layers[audio.activePadIndex].swing = 0.5 + (Float(value) / 127.0) * 0.5
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
                        // Log loop-replayed hits to terminal (not added to layers — already recorded)
                        pendingReplayHits.append((padIndex: layer.index, position: hit.position, velocity: hit.velocity))
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
                        let vel: Float = velocityMode == .full ? 1.0 : audio.layers[i].volume
                        if let idx = voicePool.allocate(sample: sample, velocity: vel, padIndex: i) {
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

        // === Signal listener: measure bus peak before master volume ===
        var preMasterPeak: Float = 0
        if clipDetectEnabled {
            for i in 0..<frameCount {
                preMasterPeak = max(preMasterPeak, abs(outputBufferL[i]), abs(outputBufferR[i]))
            }
        }

        // Apply master volume and track peak
        var peak: Float = 0
        for i in 0..<frameCount {
            outputBufferL[i] *= masterVol
            outputBufferR[i] *= masterVol
            peak = max(peak, abs(outputBufferL[i]), abs(outputBufferR[i]))
        }

        // === Signal listener: detect clipping, near-clipping, and discontinuities ===
        if clipDetectEnabled && clipCooldown <= 0 {
            // Detect discontinuities (choke pops) — sudden jump > 0.3 between consecutive samples
            var maxJump: Float = 0
            var jumpFrame: Int = 0
            if frameCount > 0 {
                let firstJumpL = abs(outputBufferL[0] - prevSampleL)
                let firstJumpR = abs(outputBufferR[0] - prevSampleR)
                let firstJump = max(firstJumpL, firstJumpR)
                if firstJump > maxJump { maxJump = firstJump; jumpFrame = 0 }
            }
            for i in 1..<frameCount {
                let jL = abs(outputBufferL[i] - outputBufferL[i-1])
                let jR = abs(outputBufferR[i] - outputBufferR[i-1])
                let j = max(jL, jR)
                if j > maxJump { maxJump = j; jumpFrame = i }
            }
            if frameCount > 0 {
                prevSampleL = outputBufferL[frameCount - 1]
                prevSampleR = outputBufferR[frameCount - 1]
            }

            // Report if: signal > 0.9 (near clip), signal > 1.0 (clip), or discontinuity > 0.3 (pop)
            let isClipping = peak > 1.0
            let isNearClip = peak > 0.9 && !isClipping
            let isPop = maxJump > 0.3

            if isClipping || isNearClip || isPop {
                clipCooldown = Int(Transport.sampleRate / 4)  // max 4 reports/sec

                // Gather per-pad info
                var clipInfo: [(pad: Int, name: String, peak: Float, vol: Float, vel: Float, samplePeak: Float, voiceCount: Int)] = []
                for p in 0..<PadBank.padCount {
                    guard frameLevels[p] > 0.001 else { continue }
                    let samplePeak: Float
                    if let sample = padBank.pads[p].sample {
                        let checkLen = min(sample.frameCount, 4096)
                        var sp: Float = 0
                        for j in 0..<checkLen { sp = max(sp, abs(sample.left[j]), abs(sample.right[j])) }
                        samplePeak = sp
                    } else {
                        samplePeak = 0
                    }
                    var vc = 0
                    for s in 0..<VoicePool.capacity {
                        if voicePool.slots[s].active && voicePool.slots[s].padIndex == p { vc += 1 }
                    }
                    let maxVel: Float = vc > 0 ? voicePool.slots.filter({ $0.active && $0.padIndex == p }).map({ $0.velocity }).max() ?? 0 : 0
                    clipInfo.append((p, padBank.pads[p].sample?.name ?? "PAD \(p+1)", frameLevels[p], audio.layers[p].volume, maxVel, samplePeak, vc))
                }

                let peakDb = peak > 0 ? 20 * log10(peak) : Float(-100)
                let preMasterDb = preMasterPeak > 0 ? 20 * log10(preMasterPeak) : Float(-100)

                let tag: String
                if isClipping {
                    tag = "⚠ CLIP \(String(format: "+%.1f", peakDb))dB"
                } else if isPop {
                    tag = "⚠ POP jump:\(String(format: "%.2f", maxJump)) @frame \(jumpFrame)"
                } else {
                    tag = "⚠ HOT \(String(format: "%.1f", peakDb))dB"
                }

                DispatchQueue.main.async { [weak self] in
                    guard let interp = self?.interpreter else { return }
                    interp.appendLine(
                        "\(tag)  bus:\(String(format: "%.1f", preMasterDb))dB  master:\(String(format: "%.0f", masterVol * 100))%",
                        kind: .system
                    )
                    for info in clipInfo {
                        let spStr = info.samplePeak > 0.95 ? " raw:\(String(format: "%.2f", info.samplePeak))" : ""
                        let vcStr = info.voiceCount > 1 ? " ×\(info.voiceCount)v" : ""
                        interp.appendLine(
                            "  pad \(info.pad+1) \(info.name.lowercased())  peak:\(String(format: "%.2f", info.peak))  vol:\(String(format: "%.0f", info.vol * 100))%  vel:\(String(format: "%.0f", info.vel * 100))%\(vcStr)\(spStr)",
                            kind: .system
                        )
                    }
                }
            }
        }
        if clipCooldown > 0 { clipCooldown -= frameCount }

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

        if wrapped {
            // Kill pad voices at loop boundary — let metronome clicks ring out
            voicePool.killPads()
        }

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

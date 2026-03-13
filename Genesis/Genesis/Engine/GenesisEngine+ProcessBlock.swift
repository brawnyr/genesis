// Genesis/Genesis/Engine/GenesisEngine+ProcessBlock.swift
import Foundation

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
        case 74: // Pad volume (knob 1)
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

        // Apply master volume and track master level
        var peak: Float = 0
        for i in 0..<frameCount {
            outputBufferL[i] *= audio.masterVolume
            outputBufferR[i] *= audio.masterVolume
            peak = max(peak, abs(outputBufferL[i]), abs(outputBufferR[i]))
        }

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

        if wrapped {
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

            // Apply pending mute changes at loop boundary
            if !audio.pendingMutes.isEmpty {
                let applied = audio.pendingMutes
                for (index, muteState) in applied {
                    audio.layers[index].isMuted = muteState
                }
                audio.pendingMutes.removeAll()
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    for (index, muteState) in applied {
                        self.layers[index].isMuted = muteState
                    }
                    self.pendingMutes.removeAll()
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
            let layerSwings = audio.layers.map { $0.swing }
            let layerIsRecording = audio.layers.map { $0.isRecording }
            let layerHasNewHits = audio.layers.map { $0.hasNewHits }
            let hits = pendingHits
            let activeIdx = audio.activePadIndex
            let activeVoicePads = voicePool.activePadIndices
            pendingHits.removeAll()
            pendingLevels = Array(repeating: 0, count: PadBank.padCount)
            pendingTriggers = Array(repeating: false, count: PadBank.padCount)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                // Sync active pad index: audio → main (MIDI hits select pads)
                self.activePadIndex = activeIdx

                if self.transport.isPlaying && !hits.isEmpty {
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                            self?.channelTriggered[i] = false
                        }
                    }
                    self.layers[i].volume = layerVolumes[i]
                    self.layers[i].pan = layerPans[i]
                    self.layers[i].hpCutoff = layerHPCutoffs[i]
                    self.layers[i].lpCutoff = layerLPCutoffs[i]
                    self.layers[i].swing = layerSwings[i]
                    self.layers[i].isRecording = layerIsRecording[i]
                    self.layers[i].hasNewHits = layerHasNewHits[i]
                }
                if let interp = self.interpreter {
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

        // Copy into destination audio buffers
        if let destL = destL, let destR = destR {
            for i in 0..<frameCount {
                destL[i] = outputBufferL[i]
                destR[i] = outputBufferR[i]
            }
        }
        os_unfair_lock_unlock(&audioLock)

        // Capture AFTER lock release — avoids heap allocations while holding spinlock
        if shouldCapture {
            outputBufferL.withUnsafeBufferPointer { leftPtr in
                outputBufferR.withUnsafeBufferPointer { rightPtr in
                    let leftSlice = UnsafeBufferPointer(rebasing: leftPtr[0..<frameCount])
                    let rightSlice = UnsafeBufferPointer(rebasing: rightPtr[0..<frameCount])
                    audio.capture.appendFromBuffers(left: leftSlice, right: rightSlice)
                }
            }
        }
    }
}

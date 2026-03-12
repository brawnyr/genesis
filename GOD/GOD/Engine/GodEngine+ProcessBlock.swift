// GOD/GOD/Engine/GodEngine+ProcessBlock.swift
import Foundation

extension GodEngine {
    // MARK: - Pad hit handling (audio thread)

    func handlePadHit(note: Int, velocity: Int, record: Bool) {
        guard let padIndex = padBank.padIndex(forNote: note),
              let sample = padBank.pads[padIndex].sample else { return }
        guard !audio.layers[padIndex].isMuted else { return }

        audio.activePadIndex = padIndex

        if record {
            audio.layers[padIndex].addHit(at: audio.position, velocity: velocity)
            audio.layers[padIndex].name = padBank.pads[padIndex].name
        }

        if audio.layers[padIndex].tcps {
            voices.removeAll { $0.padIndex == padIndex }
        }
        let vel = velocityMode == .full ? Float(1.0) : Float(velocity) / 127.0
        voices.append(Voice(sample: sample, velocity: vel, padIndex: padIndex))

        pendingHits.append((padIndex: padIndex, position: audio.position, velocity: velocity))
        pendingTriggers[padIndex] = true
    }

    func handleNoteOff(note: Int) {
        guard let padIndex = padBank.padIndex(forNote: note) else { return }
        guard !padBank.pads[padIndex].isOneShot else { return }
        voices.removeAll { $0.padIndex == padIndex }
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
        case 114: // Browse encoder — pad select
            if value < 64 {
                // Clockwise — next pad
                audio.activePadIndex = min(audio.activePadIndex + 1, PadBank.padCount - 1)
            } else {
                // Counter-clockwise — previous pad
                audio.activePadIndex = max(audio.activePadIndex - 1, 0)
            }
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
                        if layer.tcps {
                            voices.removeAll { $0.padIndex == layer.index }
                        }
                        let vel = velocityMode == .full ? Float(1.0) : Float(hit.velocity) / 127.0
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
        let frameLevels = VoiceMixer.mix(
            voices: &voices,
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
                    if muteState {
                        voices.removeAll { $0.padIndex == index }
                    }
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
            let activeIdx = audio.activePadIndex
            pendingHits.removeAll()
            pendingLevels = Array(repeating: 0, count: PadBank.padCount)
            pendingTriggers = Array(repeating: false, count: PadBank.padCount)
            DispatchQueue.main.async {
                // Sync active pad index: audio → main (MIDI hits select pads)
                self.activePadIndex = activeIdx

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

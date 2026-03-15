// Genesis/Genesis/ContentView+KeyHandlers.swift
import AppKit

extension ContentView {
    // macOS virtual key codes
    enum Key {
        static let space: UInt16 = 49
        static let a: UInt16 = 0
        static let d: UInt16 = 2
        static let w: UInt16 = 13
        static let s: UInt16 = 1
        static let q: UInt16 = 12
        static let c: UInt16 = 8
        static let g: UInt16 = 5
        static let t: UInt16 = 17
        static let b: UInt16 = 11
        static let z: UInt16 = 6
        static let x: UInt16 = 7
        static let v: UInt16 = 9
        static let m: UInt16 = 46
        static let r: UInt16 = 15
        static let y: UInt16 = 16
        static let o: UInt16 = 31
        static let returnKey: UInt16 = 36
        static let escape: UInt16 = 53
        static let upArrow: UInt16 = 126
        static let downArrow: UInt16 = 125
        static let leftArrow: UInt16 = 123
        static let rightArrow: UInt16 = 124
        static let leftBracket: UInt16 = 33
        static let rightBracket: UInt16 = 30

        // Numpad key codes
        static let numpad0: UInt16 = 82
        static let numpad1: UInt16 = 83
        static let numpad2: UInt16 = 84
        static let numpad3: UInt16 = 85
        static let numpad4: UInt16 = 86
        static let numpad5: UInt16 = 87
        static let numpad6: UInt16 = 88
        static let numpad7: UInt16 = 89
        static let numpad8: UInt16 = 91
        static let numpad9: UInt16 = 92

        static let numpadCodes: [UInt16: Int] = [
            numpad0: 0, numpad1: 1, numpad2: 2, numpad3: 3, numpad4: 4,
            numpad5: 5, numpad6: 6, numpad7: 7, numpad8: 8, numpad9: 9,
        ]
    }

    // BPM presets covering all moods
    static var bpmPresets: [(bpm: Int, mood: String)] {[
        (60,  "ambient"),
        (70,  "downtempo"),
        (80,  "chill"),
        (85,  "lofi"),
        (90,  "r&b"),
        (95,  "boom bap"),
        (100, "hip hop"),
        (110, "deep house"),
        (115, "afrobeats"),
        (120, "house"),
        (125, "uk garage"),
        (128, "techno"),
        (130, "trance"),
        (135, "jersey club"),
        (140, "dubstep"),
        (150, "footwork"),
        (160, "dnb"),
        (170, "jungle"),
        (174, "liquid dnb"),
    ]}

    func padName(_ index: Int) -> String {
        guard index >= 0, index < PadBank.padCount else { return "" }
        return engine.padBank.pads[index].sample?.name.lowercased() ?? PadBank.spliceFolderNames[index]
    }

    /// Refresh the cached file list for the current pad's folder.
    /// Only re-scans the filesystem when the pad changes.
    func refreshBrowserCache() {
        let padIndex = engine.activePadIndex
        guard padIndex != cachedBrowserPadIndex else { return }
        cachedBrowserPadIndex = padIndex
        let folderName = PadBank.spliceFolderNames[padIndex]
        let folderURL = PadBank.spliceBasePath.appendingPathComponent(folderName)
        cachedBrowserFiles = (try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            .filter { PadBank.audioExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }) ?? []
        // Reset browser index when pad changes to avoid stale out-of-bounds index
        browserIndex = 0
    }

    func loadBrowserSample() {
        refreshBrowserCache()
        let padIndex = engine.activePadIndex
        let folderName = PadBank.spliceFolderNames[padIndex]
        guard !cachedBrowserFiles.isEmpty else { return }
        browserIndex = min(browserIndex, cachedBrowserFiles.count - 1)
        let url = cachedBrowserFiles[browserIndex]
        do {
            try engine.loadSample(from: url, forPad: padIndex)
            let name = engine.padBank.pads[padIndex].sample?.name.lowercased() ?? url.lastPathComponent
            interpreter.appendLine("sample loaded → \(name) on \(folderName)", kind: .browse)
        } catch {
            interpreter.appendLine("failed to load sample: \(error.localizedDescription)", kind: .system)
        }
    }

    func browserFileName() -> String? {
        refreshBrowserCache()
        guard browserIndex >= 0, browserIndex < cachedBrowserFiles.count else { return nil }
        return cachedBrowserFiles[browserIndex].deletingPathExtension().lastPathComponent.lowercased()
    }

    func handleKey(keyCode: UInt16, chars: String?, modifiers: NSEvent.ModifierFlags) {
        switch mode {
        case .bpm:
            handleBPMKey(keyCode: keyCode, chars: chars)
        case .browse:
            handleBrowseKey(keyCode: keyCode, chars: chars, modifiers: modifiers)
        case .normal:
            handleNormalKey(keyCode: keyCode, chars: chars, modifiers: modifiers)
        }
    }

    func handleBPMKey(keyCode: UInt16, chars: String?) {
        let presets = Self.bpmPresets
        // W/S scroll through presets
        if keyCode == Key.w {
            bpmPresetIndex = max(0, bpmPresetIndex - 1)
            bpmInput = ""
            let p = presets[bpmPresetIndex]
            engine.setBPM(p.bpm)
            interpreter.appendLine("bpm → \(p.bpm) \(p.mood)", kind: .transport)
            return
        }
        if keyCode == Key.s {
            bpmPresetIndex = min(presets.count - 1, bpmPresetIndex + 1)
            bpmInput = ""
            let p = presets[bpmPresetIndex]
            engine.setBPM(p.bpm)
            interpreter.appendLine("bpm → \(p.bpm) \(p.mood)", kind: .transport)
            return
        }
        // Type digits for custom BPM
        if let c = chars?.first, c >= "0" && c <= "9" {
            bpmInput.append(c)
            interpreter.appendLine("bpm → \(bpmInput)_", kind: .transport)
            return
        }
        switch keyCode {
        case Key.returnKey:
            if let bpm = Int(bpmInput), bpm >= 1, bpm <= 999 {
                engine.setBPM(bpm)
                interpreter.appendLine("bpm set → \(engine.transport.bpm)", kind: .transport)
            } else if let bpm = Int(bpmInput), bpm > 999 {
                interpreter.appendLine("bpm must be 1–999", kind: .system)
            }
            mode = .normal
            bpmInput = ""
        case Key.escape, Key.b:
            mode = .normal
            bpmInput = ""
            interpreter.appendLine("bpm closed", kind: .transport)
        default:
            break
        }
    }

    func handleBrowseKey(keyCode: UInt16, chars: String?, modifiers: NSEvent.ModifierFlags) {
        switch keyCode {
        case Key.w, Key.upArrow:
            refreshBrowserCache()
            browserIndex = max(0, browserIndex - 1)
            loadBrowserSample()
            if let name = browserFileName() {
                interpreter.appendLine("browse → \(name)", kind: .browse)
            }
            return
        case Key.s, Key.downArrow:
            refreshBrowserCache()
            if !cachedBrowserFiles.isEmpty {
                browserIndex = min(browserIndex + 1, cachedBrowserFiles.count - 1)
            }
            loadBrowserSample()
            if let name = browserFileName() {
                interpreter.appendLine("browse → \(name)", kind: .browse)
            }
            return
        case Key.returnKey, Key.t, Key.escape:
            mode = .normal
            interpreter.appendLine("browser closed", kind: .browse)
            return
        default:
            // Fall through to normal key handling (space, A/D, etc.) preserving modifiers
            handleNormalKey(keyCode: keyCode, chars: chars, modifiers: modifiers)
        }
    }

    func handleNormalKey(keyCode: UInt16, chars: String?, modifiers: NSEvent.ModifierFlags = []) {
        let hasShift = modifiers.contains(.shift)
        let hasCmd = modifiers.contains(.command)

        switch keyCode {
        case Key.space:
            engine.togglePlay()
        case Key.g:
            // G = bounce loop audio to disk
            engine.toggleCapture()
            if engine.capture.state == .on {
                if !engine.transport.isPlaying {
                    engine.togglePlay()
                }
                interpreter.appendLine("recording to disk...", kind: .capture)
            } else {
                interpreter.appendLine("saved to ~/recordings", kind: .capture)
            }
        case Key.t:
            if hasShift {
                // Shift+T: toggle sample browser
                mode = mode == .browse ? .normal : .browse
                if mode == .browse {
                    let padIndex = engine.activePadIndex
                    let folder = PadBank.spliceFolderNames[padIndex]
                    cachedBrowserPadIndex = -1
                    refreshBrowserCache()
                    if let currentSample = engine.padBank.pads[padIndex].sample {
                        if let idx = cachedBrowserFiles.firstIndex(where: { $0.deletingPathExtension().lastPathComponent == currentSample.name }) {
                            browserIndex = idx
                        }
                    }
                    interpreter.appendLine("browser open → \(folder)", kind: .browse)
                    if let name = browserFileName() {
                        interpreter.appendLine("browse → \(name)", kind: .browse)
                    }
                }
            } else {
                // T: toggle looper on active pad
                let idx = engine.activePadIndex
                engine.toggleLooper(pad: idx)
                let looper = engine.layers[idx].looper
                interpreter.appendLine("pad \(idx + 1) \(padName(idx)) looper \(looper ? "on" : "off")", kind: .state)
            }
        case Key.a, Key.leftArrow:
            engine.activePadIndex = (engine.activePadIndex - 1 + PadBank.padCount) % PadBank.padCount
            interpreter.appendLine("pad \(engine.activePadIndex + 1) → \(padName(engine.activePadIndex))", kind: .state)
        case Key.d, Key.rightArrow:
            engine.activePadIndex = (engine.activePadIndex + 1) % PadBank.padCount
            interpreter.appendLine("pad \(engine.activePadIndex + 1) → \(padName(engine.activePadIndex))", kind: .state)
        case Key.q:
            if hasCmd && hasShift {
                // Cmd+Shift+Q: mute all pads + master
                engine.muteAll()
                if !engine.isMasterMuted { engine.toggleMasterMute() }
                interpreter.appendLine("all pads + master muted", kind: .state)
            } else if hasShift {
                // Shift+Q: toggle master mute
                engine.toggleMasterMute()
                interpreter.appendLine("master \(engine.isMasterMuted ? "muted" : "unmuted")", kind: .state)
            } else {
                // Q: toggle mute on selected pad
                let idx = engine.activePadIndex
                engine.toggleMute(layer: idx)
                let muted = engine.layers[idx].isMuted
                interpreter.appendLine("pad \(idx + 1) \(padName(idx)) \(muted ? "muted" : "unmuted")", kind: .state)
            }
        case Key.c:
            let name = padName(engine.activePadIndex)
            engine.clearLayer(engine.activePadIndex)
            interpreter.appendLine("pad \(engine.activePadIndex + 1) \(name) cleared", kind: .state)
        case Key.b:
            mode = .bpm
            bpmInput = ""
            // Snap to nearest preset
            let currentBpm = engine.transport.bpm
            let presets = Self.bpmPresets
            bpmPresetIndex = presets.enumerated().min(by: { abs($0.element.bpm - currentBpm) < abs($1.element.bpm - currentBpm) })?.offset ?? 0
            let p = presets[bpmPresetIndex]
            interpreter.appendLine("bpm mode → \(p.bpm) \(p.mood) [W↑ S↓ or type]", kind: .transport)
        case Key.escape:
            engine.stop()
            interpreter.appendLine("■ stopped", kind: .transport)
        case Key.y:
            engine.cycleBarCount(forward: true)
            interpreter.appendLine("bars → \(engine.transport.barCount)", kind: .transport)
        case Key.v:
            engine.cycleVelocityMode()
            interpreter.appendLine("velocity → \(engine.velocityMode.rawValue)", kind: .state)
        case Key.z:
            engine.undoLastClear()
            interpreter.appendLine("undo clear → pad \(engine.activePadIndex + 1)", kind: .state)
        case Key.m:
            engine.toggleMetronome()
            interpreter.appendLine("metronome \(engine.metronome.isOn ? "on" : "off")", kind: .transport)
        case Key.x:
            engine.toggleChoke(pad: engine.activePadIndex)
            let choke = engine.layers[engine.activePadIndex].choke
            let name = padName(engine.activePadIndex)
            interpreter.appendLine("pad \(engine.activePadIndex + 1) \(name) choke \(choke ? "on" : "off")", kind: .state)
        case Key.r:
            engine.toggleRecording()
            interpreter.appendLine("record \(engine.isRecording ? "armed" : "off")", kind: .capture)
        case Key.o:
            if let oracle = interpreter.oracle {
                oracle.isEnabled.toggle()
                interpreter.appendLine("oracle \(oracle.isEnabled ? "on" : "off")", kind: .oracle)
            }
        default:
            break
        }

        // Numpad-only volume control
        if let digit = Key.numpadCodes[keyCode] {
            let vol = Float(digit) / 9.0
            engine.setLayerVolume(engine.activePadIndex, volume: vol)
        }
    }
}

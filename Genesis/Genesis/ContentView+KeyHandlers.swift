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
        static let f: UInt16 = 3
        static let g: UInt16 = 5
        static let t: UInt16 = 17
        static let b: UInt16 = 11
        static let z: UInt16 = 6
        static let x: UInt16 = 7
        static let p: UInt16 = 35
            static let m: UInt16 = 46
        static let n: UInt16 = 45
        static let r: UInt16 = 15
        static let o: UInt16 = 31
        static let returnKey: UInt16 = 36
        static let escape: UInt16 = 53
        static let leftBracket: UInt16 = 33
        static let rightBracket: UInt16 = 30
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
        engine.padBank.pads[index].sample?.name.lowercased() ?? PadBank.spliceFolderNames[index]
    }

    func loadBrowserSample() {
        let padIndex = engine.activePadIndex
        let folderName = PadBank.spliceFolderNames[padIndex]
        let folderURL = PadBank.spliceBasePath.appendingPathComponent(folderName)
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            .filter { PadBank.audioExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }) ?? []
        guard !files.isEmpty else { return }
        browserIndex = min(browserIndex, files.count - 1)
        let url = files[browserIndex]
        do {
            try engine.loadSample(from: url, forPad: padIndex)
            let name = engine.padBank.pads[padIndex].sample?.name.lowercased() ?? url.lastPathComponent
            interpreter.appendLine("sample loaded → \(name) on \(folderName)", kind: .browse)
        } catch {
            interpreter.appendLine("failed to load sample: \(error.localizedDescription)", kind: .system)
        }
    }

    func browserFileName() -> String? {
        let padIndex = engine.activePadIndex
        let folderName = PadBank.spliceFolderNames[padIndex]
        let folderURL = PadBank.spliceBasePath.appendingPathComponent(folderName)
        let files = (try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            .filter { PadBank.audioExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }) ?? []
        guard browserIndex >= 0, browserIndex < files.count else { return nil }
        return files[browserIndex].deletingPathExtension().lastPathComponent.lowercased()
    }

    func handleKey(keyCode: UInt16, chars: String?, modifiers: NSEvent.ModifierFlags) {
        switch mode {
        case .bpm:
            handleBPMKey(keyCode: keyCode, chars: chars)
        case .browse:
            handleBrowseKey(keyCode: keyCode, chars: chars)
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
            if let bpm = Int(bpmInput), bpm > 0 {
                engine.setBPM(bpm)
                interpreter.appendLine("bpm set → \(bpm)", kind: .transport)
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

    func handleBrowseKey(keyCode: UInt16, chars: String?) {
        switch keyCode {
        case Key.w:
            browserIndex = max(0, browserIndex - 1)
            loadBrowserSample()
            if let name = browserFileName() {
                interpreter.appendLine("browse → \(name)", kind: .browse)
            }
            return
        case Key.s:
            let padIndex = engine.activePadIndex
            let folderName = PadBank.spliceFolderNames[padIndex]
            let folderURL = PadBank.spliceBasePath.appendingPathComponent(folderName)
            let fileCount = (try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
                .filter { PadBank.audioExtensions.contains($0.pathExtension.lowercased()) }.count) ?? 0
            if fileCount > 0 {
                browserIndex = min(browserIndex + 1, fileCount - 1)
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
            // Fall through to normal key handling (space, A/D, etc.)
            handleNormalKey(keyCode: keyCode, chars: chars, modifiers: [])
        }
    }

    func handleNormalKey(keyCode: UInt16, chars: String?, modifiers: NSEvent.ModifierFlags = []) {
        let hasShift = modifiers.contains(.shift)
        let hasCmd = modifiers.contains(.command)

        switch keyCode {
        case Key.space:
            if engine.transport.isPlaying {
                let loopSec = Double(engine.transport.loopLengthFrames) / Transport.sampleRate
                interpreter.appendLine("■ paused @ \(engine.transport.bpm)bpm \(engine.transport.barCount) bars (\(String(format: "%.1f", loopSec))s)", kind: .transport)
            } else {
                let loopSec = Double(engine.transport.loopLengthFrames) / Transport.sampleRate
                interpreter.appendLine("▶ loop start — \(engine.transport.barCount) bars @ \(engine.transport.bpm)bpm (\(String(format: "%.1f", loopSec))s)", kind: .transport)
            }
            engine.togglePlay()
        case Key.g:
            // G = bounce loop audio to disk
            engine.toggleCapture()
            if engine.capture.state == .on {
                if !engine.transport.isPlaying {
                    engine.togglePlay()
                    let loopSec = Double(engine.transport.loopLengthFrames) / Transport.sampleRate
                    interpreter.appendLine("▶ loop start — \(engine.transport.barCount) bars @ \(engine.transport.bpm)bpm (\(String(format: "%.1f", loopSec))s)", kind: .transport)
                }
                interpreter.appendLine("recording to disk...", kind: .capture)
            } else {
                interpreter.appendLine("saved to ~/recordings", kind: .capture)
            }
        case Key.t:
            mode = mode == .browse ? .normal : .browse
            if mode == .browse {
                let folder = PadBank.spliceFolderNames[engine.activePadIndex]
                interpreter.appendLine("browser open → \(folder)", kind: .browse)
                if let name = browserFileName() {
                    interpreter.appendLine("browse → \(name)", kind: .browse)
                }
            }
        case Key.a:
            engine.activePadIndex = (engine.activePadIndex - 1 + PadBank.padCount) % PadBank.padCount
            interpreter.appendLine("pad \(engine.activePadIndex + 1) → \(padName(engine.activePadIndex))", kind: .state)
        case Key.d:
            engine.activePadIndex = (engine.activePadIndex + 1) % PadBank.padCount
            interpreter.appendLine("pad \(engine.activePadIndex + 1) → \(padName(engine.activePadIndex))", kind: .state)
        case Key.f:
            let idx = engine.activePadIndex
            if hasShift {
                // Shift+F: queue pad to fire at beat 1 of next loop
                engine.queuePad(idx)
                interpreter.appendLine("pad \(idx + 1) \(padName(idx)) queued", kind: .state)
            }
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
                if engine.toggleMode == .nextLoop {
                    if let pending = engine.pendingMutes[idx] {
                        interpreter.appendLine("pad \(idx + 1) \(padName(idx)) \(pending ? "mute" : "unmute") queued for next loop", kind: .state)
                    } else {
                        interpreter.appendLine("pad \(idx + 1) \(padName(idx)) queue cancelled", kind: .state)
                    }
                } else {
                    let muted = engine.layers[idx].isMuted
                    interpreter.appendLine("pad \(idx + 1) \(padName(idx)) \(muted ? "muted" : "unmuted")", kind: .state)
                }
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
        case Key.leftBracket:
            engine.cycleBarCount(forward: false)
            interpreter.appendLine("bars → \(engine.transport.barCount)", kind: .transport)
        case Key.rightBracket:
            engine.cycleBarCount(forward: true)
            interpreter.appendLine("bars → \(engine.transport.barCount)", kind: .transport)
        case Key.p:
            engine.cycleVelocityMode()
            interpreter.appendLine("velocity → \(engine.velocityMode.rawValue)", kind: .state)
        case Key.z:
            engine.undoLastClear()
            interpreter.appendLine("undo clear → pad \(engine.activePadIndex + 1)", kind: .state)
        case Key.n:
            engine.cycleToggleMode()
            interpreter.appendLine("queued mutes \(engine.toggleMode == .nextLoop ? "on" : "off")", kind: .state)
        case Key.m:
            engine.toggleMetronome()
            interpreter.appendLine("metronome \(engine.metronome.isOn ? "on" : "off")", kind: .transport)
        case Key.x:
            engine.toggleChoke(pad: engine.activePadIndex)
            let choke = engine.layers[engine.activePadIndex].choke
            let name = padName(engine.activePadIndex)
            interpreter.appendLine("pad \(engine.activePadIndex + 1) \(name) choke \(choke ? "on" : "off")", kind: .state)
        case Key.r:
            let idx = engine.activePadIndex
            engine.toggleLooper(pad: idx)
            let looper = engine.layers[idx].looper
            interpreter.appendLine("pad \(idx + 1) \(padName(idx)) looper \(looper ? "on" : "off")", kind: .state)
        case Key.o:
            if let oracle = interpreter.oracle {
                oracle.isEnabled.toggle()
                interpreter.appendLine("oracle \(oracle.isEnabled ? "on" : "off")", kind: .oracle)
            }
        default:
            break
        }

        if let c = chars?.first {
            switch c {
            case "0"..."9":
                guard let asciiVal = c.asciiValue, let zeroVal = Character("0").asciiValue else { break }
                let digit = Float(asciiVal - zeroVal)
                engine.setLayerVolume(engine.activePadIndex, volume: digit / 9.0)
                let pDb = formatDb(linearToDb(digit / 9.0))
                interpreter.appendLine("pad \(engine.activePadIndex + 1) vol → \(Int(digit / 9.0 * 100))% (\(pDb))", kind: .state)
            default: break
            }
        }
    }
}

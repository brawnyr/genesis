// Genesis/Genesis/Engine/SessionOracle.swift
import Foundation
import os

private let logger = Logger(subsystem: "genesis", category: "SessionOracle")

class SessionOracle {
    var isEnabled: Bool = false {
        didSet {
            if isEnabled { ensureOllamaRunning() }
        }
    }
    weak var interpreter: EngineEventInterpreter?

    private let endpoint = URL(string: "http://localhost:11434/api/generate")!
    private let model = "mistral"
    private var previousSnapshot: Snapshot?
    private var loopsSinceLastComment: Int = 0
    private let minLoopsBetween: Int = 3
    private var pendingRequest: Bool = false
    private var ollamaProcess: Process?
    private var ollamaChecked: Bool = false

    deinit {
        stopOllama()
    }

    // MARK: - Ollama process management

    private func ensureOllamaRunning() {
        guard !ollamaChecked else { return }
        ollamaChecked = true

        // Quick health check — if already running, skip launch
        var probe = URLRequest(url: URL(string: "http://localhost:11434/")!)
        probe.timeoutInterval = 2
        URLSession.shared.dataTask(with: probe) { [weak self] _, response, error in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                logger.info("Ollama already running")
                DispatchQueue.main.async {
                    self?.interpreter?.appendLine("oracle connected to ollama", kind: .oracle)
                }
                return
            }
            self?.launchOllama()
        }.resume()
    }

    private func launchOllama() {
        // Find ollama binary
        let paths = ["/opt/homebrew/bin/ollama", "/usr/local/bin/ollama"]
        guard let bin = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            logger.warning("ollama not found — install with: brew install ollama")
            DispatchQueue.main.async { [weak self] in
                self?.interpreter?.appendLine("oracle: ollama not found — brew install ollama", kind: .oracle)
                self?.isEnabled = false
            }
            ollamaChecked = false
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: bin)
        proc.arguments = ["serve"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            ollamaProcess = proc
            logger.info("Launched ollama serve (pid \(proc.processIdentifier))")

            // Wait a moment for it to bind the port, then confirm
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in
                DispatchQueue.main.async {
                    self?.interpreter?.appendLine("oracle: ollama started", kind: .oracle)
                }
            }
        } catch {
            logger.error("Failed to launch ollama: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.interpreter?.appendLine("oracle: failed to start ollama", kind: .oracle)
                self?.isEnabled = false
            }
            ollamaChecked = false
        }
    }

    func stopOllama() {
        if let proc = ollamaProcess, proc.isRunning {
            proc.terminate()
            logger.info("Terminated ollama serve")
        }
        ollamaProcess = nil
        ollamaChecked = false
    }

    // MARK: - Loop boundary

    func onLoopBoundary(layers: [Layer], padBank: PadBank, transport: Transport) {
        guard isEnabled, !pendingRequest else { return }

        let snap = Snapshot(
            bpm: transport.bpm,
            barCount: transport.barCount,
            isPlaying: transport.isPlaying,
            pads: (0..<PadBank.padCount).map { i in
                let layer = layers[i]
                let pad = padBank.pads[i]
                return PadSnapshot(
                    name: pad.sample?.name ?? PadBank.spliceFolderNames[i],
                    volume: layer.volume,
                    isMuted: layer.isMuted,
                    looper: layer.looper,
                    hitCount: layer.hits.count,
                    pan: layer.pan,
                    hpCutoff: layer.hpCutoff,
                    lpCutoff: layer.lpCutoff,
                    swing: layer.swing
                )
            }
        )

        loopsSinceLastComment += 1

        let changes = diff(old: previousSnapshot, new: snap)
        previousSnapshot = snap

        guard loopsSinceLastComment >= minLoopsBetween else { return }
        guard interestScore(changes: changes, snapshot: snap) > 0 else { return }

        loopsSinceLastComment = 0
        pendingRequest = true
        requestComment(snapshot: snap, changes: changes)
    }

    // MARK: - Diffing

    private struct Snapshot {
        let bpm: Int
        let barCount: Int
        let isPlaying: Bool
        let pads: [PadSnapshot]
    }

    private struct PadSnapshot {
        let name: String
        let volume: Float
        let isMuted: Bool
        let looper: Bool
        let hitCount: Int
        let pan: Float
        let hpCutoff: Float
        let lpCutoff: Float
        let swing: Float
    }

    private func diff(old: Snapshot?, new: Snapshot) -> [String] {
        guard let old else { return ["session just started"] }
        var changes: [String] = []

        if old.bpm != new.bpm {
            changes.append("BPM changed from \(old.bpm) to \(new.bpm)")
        }
        if old.barCount != new.barCount {
            changes.append("Bar count changed from \(old.barCount) to \(new.barCount)")
        }
        if old.isPlaying != new.isPlaying {
            changes.append(new.isPlaying ? "Playback started" : "Playback stopped")
        }

        for i in 0..<min(old.pads.count, new.pads.count) {
            let o = old.pads[i]
            let n = new.pads[i]
            if o.isMuted != n.isMuted {
                changes.append("\(n.name) \(n.isMuted ? "muted" : "unmuted")")
            }
            if abs(o.volume - n.volume) > 0.05 {
                changes.append("\(n.name) volume → \(Int(n.volume * 100))%")
            }
            if o.looper != n.looper {
                changes.append("\(n.name) looper \(n.looper ? "enabled" : "disabled")")
            }
            if o.hitCount != n.hitCount && n.hitCount > 0 && o.hitCount == 0 {
                changes.append("\(n.name) has new hits recorded")
            }
            if o.name != n.name {
                changes.append("Pad \(i + 1) sample changed to \(n.name)")
            }
        }

        return changes
    }

    private func interestScore(changes: [String], snapshot: Snapshot) -> Int {
        if changes.isEmpty { return 0 }
        var score = changes.count
        if changes.contains(where: { $0.contains("started") || $0.contains("stopped") }) {
            score += 2
        }
        if changes.contains(where: { $0.contains("new hits") }) {
            score += 2
        }
        return score
    }

    // MARK: - Ollama request

    private func requestComment(snapshot: Snapshot, changes: [String]) {
        let activePads = snapshot.pads.enumerated()
            .filter { $0.element.hitCount > 0 || $0.element.looper }
            .map { "\($0.element.name) (vol:\(Int($0.element.volume * 100))%\($0.element.isMuted ? " MUTED" : "")\($0.element.looper ? " LOOP" : ""))" }

        let context = """
        BPM: \(snapshot.bpm), Bars: \(snapshot.barCount), Playing: \(snapshot.isPlaying)
        Active pads: \(activePads.isEmpty ? "none" : activePads.joined(separator: ", "))
        Recent changes: \(changes.joined(separator: "; "))
        """

        let payload: [String: Any] = [
            "model": model,
            "prompt": context,
            "system": "You are a concise, poetic observer of a live music production session in a loop-based instrument called Genesis. Comment on what is happening in 1-2 short sentences. Be specific about the sounds and changes you notice. No emojis. Keep it cryptic and cool. Do not explain what you are doing.",
            "stream": false,
            "options": ["temperature": 0.9, "num_predict": 60]
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            pendingRequest = false
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            defer { DispatchQueue.main.async { self?.pendingRequest = false } }
            guard let data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let response = json["response"] as? String else { return }

            let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            DispatchQueue.main.async {
                self?.interpreter?.appendLine(trimmed, kind: .oracle)
            }
        }.resume()
    }
}

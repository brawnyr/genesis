import Foundation
import os

private let logger = Logger(subsystem: "com.god.llm", category: "LLMManager")

class LLMManager {
    private let terminalState: TerminalState
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private let queue = DispatchQueue(label: "com.god.llm", qos: .utility)
    private var lastRequestTime: Date = .distantPast
    private var _pendingRequestCount = 0
    private let debounceInterval: TimeInterval = 2.0
    private let timeoutInterval: TimeInterval = 3.0
    private var isRunning = false
    private var lastSnapshotJSON: String?

    var pendingRequestCount: Int {
        queue.sync { _pendingRequestCount }
    }

    static let modelsDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".god")
            .appendingPathComponent("models")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static let systemPrompt = """
    You are a studio session observer for GOD, a loop-stacking instrument. \
    You receive JSON snapshots of the engine state. Respond with 1-2 short lines \
    of commentary about what's happening musically. Be warm, conversational, \
    and accurate. Note truncated samples, frequency overlaps, filter settings, \
    and rhythmic patterns. Don't be stiff — talk like a studio partner in the room.
    """

    init(terminalState: TerminalState) {
        self.terminalState = terminalState
    }

    func start() {
        guard let modelFile = findModelFile() else {
            // Synchronous — no subprocess work needed, no need for async dispatch
            terminalState.setStatus("no model loaded — drop a gguf into ~/.god/models/")
            return
        }

        guard let llamaBinary = findLlamaBinary() else {
            terminalState.setStatus("llama-cli not found — install llama.cpp")
            return
        }

        queue.async { [weak self] in
            self?.launchProcess(binary: llamaBinary, model: modelFile)
        }
    }

    func stop() {
        isRunning = false
        process?.terminate()
        process = nil
    }

    func requestInference(snapshot: StateSnapshot) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let now = Date()
            guard now.timeIntervalSince(self.lastRequestTime) >= self.debounceInterval else { return }
            guard self._pendingRequestCount == 0 else { return }
            guard self.isRunning else { return }

            // Skip if state hasn't changed since last request
            if let json = try? JSONEncoder().encode(snapshot),
               let jsonStr = String(data: json, encoding: .utf8),
               jsonStr == self.lastSnapshotJSON { return }

            self.lastRequestTime = now
            self._pendingRequestCount += 1
            self.sendRequest(snapshot: snapshot)
        }
    }

    private func findModelFile() -> URL? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: Self.modelsDir, includingPropertiesForKeys: nil) else { return nil }
        return contents.first { $0.pathExtension == "gguf" }
    }

    private func findLlamaBinary() -> String? {
        let candidates = [
            "/usr/local/bin/llama-cli",
            "/opt/homebrew/bin/llama-cli",
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    private func launchProcess(binary: String, model: URL) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binary)
        proc.arguments = [
            "-m", model.path,
            "--interactive",
            "-c", "2048",
            "--temp", "0.7",
            "-p", Self.systemPrompt
        ]

        let stdin = Pipe()
        let stdout = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            self.process = proc
            self.stdinPipe = stdin
            self.stdoutPipe = stdout
            self.isRunning = true

            // Detect crashes
            proc.terminationHandler = { [weak self] _ in
                self?.isRunning = false
                self?.queue.async { self?._pendingRequestCount = 0 }
                DispatchQueue.main.async {
                    self?.terminalState.append("model disconnected")
                }
            }

            DispatchQueue.main.async {
                self.terminalState.append("genesis terminal online", highlight: true)
            }

            readOutput(from: stdout)
        } catch {
            logger.error("Failed to launch llama: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.terminalState.setStatus("model disconnected")
            }
        }
    }

    private func readOutput(from pipe: Pipe) {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            self?.queue.async { self?._pendingRequestCount = 0 }

            DispatchQueue.main.async {
                for line in trimmed.components(separatedBy: .newlines) {
                    let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleaned.isEmpty else { continue }
                    self?.terminalState.append(cleaned)
                }
            }
        }
    }

    private func sendRequest(snapshot: StateSnapshot) {
        guard let pipe = stdinPipe else {
            _pendingRequestCount = 0
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let json = try encoder.encode(snapshot)
            guard var text = String(data: json, encoding: .utf8) else { return }
            lastSnapshotJSON = text
            text += "\n"

            pipe.fileHandleForWriting.write(text.data(using: .utf8)!)

            queue.asyncAfter(deadline: .now() + timeoutInterval) { [weak self] in
                if self?._pendingRequestCount ?? 0 > 0 {
                    self?._pendingRequestCount = 0
                }
            }
        } catch {
            _pendingRequestCount = 0
        }
    }

    deinit {
        stop()
    }
}

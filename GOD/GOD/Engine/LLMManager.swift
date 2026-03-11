import Foundation
import os

private let logger = Logger(subsystem: "com.god.llm", category: "LLMManager")

class LLMManager {
    private let terminalState: TerminalState
    private var process: Process?
    private let queue = DispatchQueue(label: "com.god.llm", qos: .utility)
    private var lastRequestTime: Date = .distantPast
    private var _pendingRequestCount = 0
    private let debounceInterval: TimeInterval = 2.0
    private let timeoutInterval: TimeInterval = 3.0
    private var isRunning = false
    private var lastSnapshotJSON: String?
    private let port = 8421
    private let session = URLSession(configuration: .ephemeral)

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
            terminalState.setStatus("no model loaded — drop a gguf into ~/.god/models/")
            return
        }

        guard let serverBinary = findServerBinary() else {
            terminalState.setStatus("llama-server not found — install llama.cpp")
            return
        }

        queue.async { [weak self] in
            self?.launchServer(binary: serverBinary, model: modelFile)
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
            self.sendHTTPRequest(snapshot: snapshot)
        }
    }

    private func findModelFile() -> URL? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: Self.modelsDir, includingPropertiesForKeys: nil) else { return nil }
        return contents.first { $0.pathExtension == "gguf" }
    }

    private func findServerBinary() -> String? {
        let candidates = [
            "/usr/local/bin/llama-server",
            "/opt/homebrew/bin/llama-server",
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    private func launchServer(binary: String, model: URL) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binary)
        proc.arguments = [
            "-m", model.path,
            "--port", String(port),
            "-c", "2048",
            "--temp", "0.7",
            "-ngl", "99",  // offload all layers to GPU/Metal
        ]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            self.process = proc

            proc.terminationHandler = { [weak self] _ in
                self?.isRunning = false
                self?.queue.async { self?._pendingRequestCount = 0 }
                DispatchQueue.main.async {
                    self?.terminalState.append("model disconnected")
                }
            }

            // Wait for server to be ready (poll /health)
            waitForServer { [weak self] success in
                guard let self = self else { return }
                if success {
                    self.isRunning = true
                    DispatchQueue.main.async {
                        self.terminalState.append("genesis terminal online", highlight: true)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.terminalState.setStatus("model failed to start")
                    }
                    proc.terminate()
                }
            }
        } catch {
            logger.error("Failed to launch llama-server: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.terminalState.setStatus("model disconnected")
            }
        }
    }

    private func waitForServer(attempts: Int = 30, completion: @escaping (Bool) -> Void) {
        let url = URL(string: "http://127.0.0.1:\(port)/health")!
        var remaining = attempts

        func check() {
            let task = session.dataTask(with: url) { data, response, _ in
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    completion(true)
                } else {
                    remaining -= 1
                    if remaining > 0 {
                        self.queue.asyncAfter(deadline: .now() + 1.0) { check() }
                    } else {
                        completion(false)
                    }
                }
            }
            task.resume()
        }

        queue.asyncAfter(deadline: .now() + 1.0) { check() }
    }

    private func sendHTTPRequest(snapshot: StateSnapshot) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let snapshotData = try? encoder.encode(snapshot),
              let snapshotJSON = String(data: snapshotData, encoding: .utf8) else {
            queue.async { self._pendingRequestCount = 0 }
            return
        }

        lastSnapshotJSON = snapshotJSON

        let requestBody: [String: Any] = [
            "messages": [
                ["role": "system", "content": Self.systemPrompt],
                ["role": "user", "content": snapshotJSON]
            ],
            "max_tokens": 100,
            "temperature": 0.7,
            "stream": false
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            queue.async { self._pendingRequestCount = 0 }
            return
        }

        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        request.timeoutInterval = timeoutInterval

        let task = session.dataTask(with: request) { [weak self] data, _, error in
            defer { self?.queue.async { self?._pendingRequestCount = 0 } }

            guard let data = data, error == nil else { return }

            // Parse OpenAI-compatible response
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any],
                  let content = message["content"] as? String else { return }

            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            DispatchQueue.main.async {
                for line in trimmed.components(separatedBy: .newlines) {
                    let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleaned.isEmpty else { continue }
                    self?.terminalState.append(cleaned)
                }
            }
        }
        task.resume()
    }

    deinit {
        stop()
    }
}

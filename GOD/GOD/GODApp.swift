import SwiftUI
import AppKit
import os

private let logger = Logger(subsystem: "god", category: "GODApp")

// MARK: - Crash logging

private let crashLogURL: URL = {
    let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".god")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("crash.log")
}()

private func writeCrashLog(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let entry = "[\(timestamp)] \(message)\n"
    if let data = entry.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: crashLogURL.path) {
            if let handle = try? FileHandle(forWritingTo: crashLogURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: crashLogURL)
        }
    }
}

private func installCrashHandlers() {
    // Objective-C uncaught exceptions
    NSSetUncaughtExceptionHandler { exception in
        let info = """
        UNCAUGHT EXCEPTION: \(exception.name.rawValue)
        Reason: \(exception.reason ?? "unknown")
        Stack:\n\(exception.callStackSymbols.joined(separator: "\n"))
        """
        writeCrashLog(info)
    }

    // Signal handlers for crashes Swift doesn't catch as exceptions
    let signals: [(Int32, String)] = [
        (SIGABRT, "SIGABRT"), (SIGSEGV, "SIGSEGV"), (SIGBUS, "SIGBUS"),
        (SIGFPE, "SIGFPE"), (SIGILL, "SIGILL"), (SIGTRAP, "SIGTRAP")
    ]
    for (sig, _) in signals {
        signal(sig) { sigNum in
            let names: [Int32: String] = [
                SIGABRT: "SIGABRT", SIGSEGV: "SIGSEGV", SIGBUS: "SIGBUS",
                SIGFPE: "SIGFPE", SIGILL: "SIGILL", SIGTRAP: "SIGTRAP"
            ]
            let name = names[sigNum] ?? "SIGNAL \(sigNum)"
            // Can't do much in a signal handler — write minimal info
            let msg = "\(name) — app crashed. Check Console.app for full stack trace."
            writeCrashLog(msg)
            // Re-raise to get default behavior (core dump / crash report)
            signal(sigNum, SIG_DFL)
            raise(sigNum)
        }
    }
}

@main
struct GODApp: App {
    @StateObject private var engine = GodEngine()
    @StateObject private var interpreter = EngineEventInterpreter()
    @State private var audioManager: AudioManager?
    @State private var midiManager: MIDIManager?

    init() {
        installCrashHandlers()
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.applicationIconImage = Self.generateIcon()
    }

    // Programmatic dock icon — "GENESIS" text on dark bg
    private static func generateIcon() -> NSImage {
        let size: CGFloat = 512
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        // Background — dark rounded rect
        let bg = NSColor(red: 0.102, green: 0.098, blue: 0.090, alpha: 1)
        let path = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: 100, yRadius: 100)
        bg.setFill()
        path.fill()

        // "GENESIS" in orange monospace
        let orange = NSColor(red: 0.855, green: 0.482, blue: 0.290, alpha: 1)
        let font = NSFont.monospacedSystemFont(ofSize: 64, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: orange,
        ]
        let text = NSAttributedString(string: "GENESIS", attributes: attrs)
        let textSize = text.size()
        let textX = (size - textSize.width) / 2
        let textY = (size - textSize.height) / 2
        text.draw(at: NSPoint(x: textX, y: textY))

        image.unlockFocus()
        return image
    }


    var body: some Scene {
        WindowGroup {
            ContentView(engine: engine, interpreter: interpreter)
                .onAppear {
                    startManagers()
                    NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
                }
                .onDisappear {
                    stopManagers()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)
    }

    private func startManagers() {
        ensureSpliceFolders()

        do {
            try engine.padBank.loadConfig()
        } catch {
            logger.info("No saved pad config (or error loading): \(error.localizedDescription)")
        }
        engine.padBank.loadFromSpliceFolders()
        engine.restoreTcpsFromPadBank()
        for i in 0..<PadBank.padCount {
            engine.detectBPM(forPad: i)
        }
        do {
            try engine.padBank.save()
        } catch {
            logger.error("Failed to save pad config: \(error.localizedDescription)")
        }

        // Wire interpreter
        engine.interpreter = interpreter

        // Log startup
        interpreter.appendLine("god initialized", kind: .system)
        let loadedCount = engine.padBank.pads.filter { $0.sample != nil }.count
        if loadedCount > 0 {
            interpreter.appendLine("\(loadedCount) samples loaded from config", kind: .system)
        }
        for (i, pad) in engine.padBank.pads.enumerated() {
            if let sample = pad.sample {
                interpreter.appendLine("  pad \(i + 1) \(PadBank.spliceFolderNames[i]) → \(sample.name.lowercased())", kind: .system)
            }
        }

        let audio = AudioManager(engine: engine)
        do {
            try audio.start()
        } catch {
            logger.error("Audio engine failed to start: \(error.localizedDescription)")
        }
        audioManager = audio

        let midi = MIDIManager(ringBuffer: engine.midiRingBuffer)
        midi.interpreter = interpreter
        midi.start()
        midiManager = midi
    }

    private func stopManagers() {
        audioManager?.stop()
        midiManager?.stop()
    }

    private func ensureSpliceFolders() {
        let fm = FileManager.default
        for name in PadBank.spliceFolderNames {
            let url = PadBank.spliceBasePath.appendingPathComponent(name)
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}

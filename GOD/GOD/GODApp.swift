import SwiftUI
import AppKit
import os

private let logger = Logger(subsystem: "com.god.app", category: "GODApp")

@main
struct GODApp: App {
    @StateObject private var engine = GodEngine()
    @StateObject private var interpreter = EngineEventInterpreter()
    @State private var audioManager: AudioManager?
    @State private var midiManager: MIDIManager?

    init() {
        // When running as raw binary (not .app bundle), register as a regular app
        if Bundle.main.bundlePath.hasSuffix(".app") == false {
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        NSApplication.shared.applicationIconImage = Self.generateIcon()
    }

    // Programmatic dock icon — pixel GOD on dark bg
    private static func generateIcon() -> NSImage {
        let size: CGFloat = 512
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        // Background — dark rounded rect
        let bg = NSColor(red: 0.102, green: 0.098, blue: 0.090, alpha: 1)
        let path = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: 100, yRadius: 100)
        bg.setFill()
        path.fill()

        // Pixel grid for G, O, D — 7 wide x 9 tall each
        let letters: [[[Bool]]] = [
            // G
            [
                [false,true,true,true,true,true,false],
                [true,true,false,false,false,true,true],
                [true,true,false,false,false,false,false],
                [true,true,false,false,false,false,false],
                [true,true,false,true,true,true,false],
                [true,true,false,false,false,true,true],
                [true,true,false,false,false,true,true],
                [true,true,false,false,false,true,true],
                [false,true,true,true,true,true,false],
            ],
            // O
            [
                [false,true,true,true,true,true,false],
                [true,true,false,false,false,true,true],
                [true,true,false,false,false,true,true],
                [true,true,false,false,false,true,true],
                [true,true,false,false,false,true,true],
                [true,true,false,false,false,true,true],
                [true,true,false,false,false,true,true],
                [true,true,false,false,false,true,true],
                [false,true,true,true,true,true,false],
            ],
            // D
            [
                [true,true,true,true,true,false,false],
                [true,true,false,false,true,true,false],
                [true,true,false,false,false,true,true],
                [true,true,false,false,false,true,true],
                [true,true,false,false,false,true,true],
                [true,true,false,false,false,true,true],
                [true,true,false,false,false,true,true],
                [true,true,false,false,true,true,false],
                [true,true,true,true,true,false,false],
            ],
        ]

        let pixelSize: CGFloat = 14
        let gap: CGFloat = 4
        let cellSize = pixelSize + gap
        let letterW = 7 * cellSize
        let letterSpacing: CGFloat = 28
        let totalW = 3 * letterW + 2 * letterSpacing
        let totalH = 9 * cellSize
        let startX = (size - totalW) / 2
        let startY = (size - totalH) / 2

        let orange = NSColor(red: 0.855, green: 0.482, blue: 0.290, alpha: 1)

        for (li, letter) in letters.enumerated() {
            let lx = startX + CGFloat(li) * (letterW + letterSpacing)
            for (row, bits) in letter.enumerated() {
                for (col, on) in bits.enumerated() {
                    guard on else { continue }
                    let x = lx + CGFloat(col) * cellSize
                    // Flip Y since NSImage draws bottom-up
                    let y = startY + CGFloat(8 - row) * cellSize
                    orange.setFill()
                    NSRect(x: x, y: y, width: pixelSize, height: pixelSize).fill()
                }
            }
        }

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
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)
    }

    private func startManagers() {
        ensureSpliceFolders()

        try? engine.padBank.loadConfig()
        engine.padBank.loadFromSpliceFolders()
        engine.restoreCutFromPadBank()
        try? engine.padBank.save()

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
        midi.start()
        midiManager = midi
    }

    private func ensureSpliceFolders() {
        let fm = FileManager.default
        for name in PadBank.spliceFolderNames {
            let url = PadBank.spliceBasePath.appendingPathComponent(name)
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}

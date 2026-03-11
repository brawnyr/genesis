import SwiftUI
import AppKit
import os

private let logger = Logger(subsystem: "com.god.app", category: "GODApp")

@main
struct GODApp: App {
    @StateObject private var engine = GodEngine()
    @State private var audioManager: AudioManager?
    @State private var midiManager: MIDIManager?

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(engine: engine)
                .onAppear {
                    startManagers()
                    NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 700)
    }

    private func startManagers() {
        // Create Splice folders if they don't exist
        ensureSpliceFolders()

        // Load saved pad config, then fill gaps from Splice folders
        try? engine.padBank.loadConfig()
        engine.padBank.loadFromSpliceFolders()
        try? engine.padBank.save()

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

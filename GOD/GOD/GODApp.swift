import SwiftUI
import AppKit

@main
struct GODApp: App {
    @StateObject private var engine = GodEngine()
    @State private var audioManager: AudioManager?
    @State private var midiManager: MIDIManager?

    init() {
        // Activate as a foreground app so the window gets focus from terminal
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(engine: engine)
                .onAppear {
                    startManagers()
                    // Ensure window is key and front
                    NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 700)
    }

    private func startManagers() {
        let audio = AudioManager(engine: engine)
        try? audio.start()
        audioManager = audio

        let midi = MIDIManager(ringBuffer: engine.midiRingBuffer)
        midi.start()
        midiManager = midi
    }
}

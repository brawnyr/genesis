import SwiftUI

@main
struct GODApp: App {
    @StateObject private var engine = GodEngine()
    @State private var audioManager: AudioManager?
    @State private var midiManager: MIDIManager?

    var body: some Scene {
        WindowGroup {
            ContentView(engine: engine)
                .onAppear {
                    startManagers()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 700)
    }

    private func startManagers() {
        let audio = AudioManager(engine: engine)
        try? audio.start()
        audioManager = audio

        let midi = MIDIManager(engine: engine)
        midi.start()
        midiManager = midi
    }
}

import Testing
@testable import GOD

@Test @MainActor func engineInitialState() {
    let engine = GodEngine()
    #expect(engine.transport.bpm == 120)
    #expect(engine.transport.isPlaying == false)
    #expect(engine.layers.count == 8)
    #expect(engine.capture.state == .idle)
}

@Test @MainActor func engineTogglePlay() {
    let engine = GodEngine()
    engine.togglePlay()
    #expect(engine.transport.isPlaying == true)
    engine.togglePlay()
    #expect(engine.transport.isPlaying == false)
}

@Test @MainActor func engineSetBPM() {
    let engine = GodEngine()
    engine.setBPM(140)
    #expect(engine.transport.bpm == 140)
}

@Test @MainActor func engineToggleMute() {
    let engine = GodEngine()
    engine.toggleMute(layer: 0)
    #expect(engine.layers[0].isMuted == true)
    engine.toggleMute(layer: 0)
    #expect(engine.layers[0].isMuted == false)
}

@Test @MainActor func engineClearLayer() {
    let engine = GodEngine()
    engine.layers[0].addHit(at: 100, velocity: 100)
    engine.clearLayer(0)
    #expect(engine.layers[0].hits.count == 0)
}

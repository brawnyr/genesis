import Testing
@testable import Genesis

@Test func muteChangeDiffZerosIntensity() {
    let interpreter = EngineEventInterpreter()
    var layers = (0..<8).map { Layer(index: $0, name: "PAD \($0 + 1)") }
    var bank = PadBank()
    let sample = Sample(name: "kick", left: [0.1], right: [0.1], sampleRate: 44100)
    bank.assign(sample: sample, toPad: 3)

    // Give pad 3 some intensity
    interpreter.padIntensities[3] = 0.8

    // Establish baseline
    interpreter.processStateDiff(layers: layers, transport: Transport(),
                                  capture: GenesisCapture(), padBank: bank, masterVolume: 1.0)

    // Mute pad 3 — intensity should zero out
    layers[3].isMuted = true
    interpreter.processStateDiff(layers: layers, transport: Transport(),
                                  capture: GenesisCapture(), padBank: bank, masterVolume: 1.0)

    #expect(interpreter.padIntensities[3] == 0)
}

@Test func hpLpDiffEmitsEvent() {
    let interpreter = EngineEventInterpreter()
    var layers = (0..<8).map { Layer(index: $0, name: "PAD \($0 + 1)") }

    interpreter.processStateDiff(layers: layers, transport: Transport(),
                                  capture: GenesisCapture(), padBank: PadBank(), masterVolume: 1.0)

    layers[1].hpCutoff = 500
    layers[1].lpCutoff = 4200
    // Call multiple times to pass debounce settle threshold
    for _ in 0..<5 {
        interpreter.processStateDiff(layers: layers, transport: Transport(),
                                      capture: GenesisCapture(), padBank: PadBank(), masterVolume: 1.0)
    }

    #expect(interpreter.lines.contains { $0.text.contains("HP → 500Hz") })
    #expect(interpreter.lines.contains { $0.text.contains("LP → 4.2kHz") })
}

@Test func loopBoundarySummary() {
    let interpreter = EngineEventInterpreter()
    var bank = PadBank()
    let sample = Sample(name: "hats", left: [0.1], right: [0.1], sampleRate: 44100)
    bank.assign(sample: sample, toPad: 2)

    interpreter.processHits([
        (padIndex: 2, position: 0, velocity: 95),
        (padIndex: 2, position: 1000, velocity: 100),
        (padIndex: 2, position: 2000, velocity: 98),
        (padIndex: 2, position: 3000, velocity: 104),
    ], padBank: bank, loopDurationMs: 8000)

    let layers = (0..<8).map { Layer(index: $0, name: "PAD \($0 + 1)") }
    interpreter.onLoopBoundary(layers: layers, padBank: bank, loopDurationMs: 8000)

    guard let summaryLine = interpreter.lines.last else {
        Issue.record("Expected at least one line after loop boundary")
        return
    }
    #expect(summaryLine.text.contains("hats"))
    #expect(summaryLine.text.contains("4 hits"))
    #expect(summaryLine.text.contains("tight"))
}

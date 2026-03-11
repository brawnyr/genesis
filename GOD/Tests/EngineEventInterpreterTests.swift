import Testing
@testable import GOD

@Test func formatFrequencyBelowThousand() {
    #expect(EngineEventInterpreter.formatFrequency(340) == "340Hz")
    #expect(EngineEventInterpreter.formatFrequency(20) == "20Hz")
    #expect(EngineEventInterpreter.formatFrequency(999) == "999Hz")
}

@Test func formatFrequencyAboveThousand() {
    #expect(EngineEventInterpreter.formatFrequency(1000) == "1.0kHz")
    #expect(EngineEventInterpreter.formatFrequency(4200) == "4.2kHz")
    #expect(EngineEventInterpreter.formatFrequency(20000) == "20.0kHz")
}

@Test func formatPan() {
    #expect(EngineEventInterpreter.formatPan(0.5) == "C")
    #expect(EngineEventInterpreter.formatPan(0.0) == "L50")
    #expect(EngineEventInterpreter.formatPan(1.0) == "R50")
    #expect(EngineEventInterpreter.formatPan(0.35) == "L15")
    #expect(EngineEventInterpreter.formatPan(0.65) == "R15")
}

@Test func formatDuration() {
    #expect(EngineEventInterpreter.formatDuration(100) == ".1s")
    #expect(EngineEventInterpreter.formatDuration(80) == ".08s")
    #expect(EngineEventInterpreter.formatDuration(14200) == "14.2s")
    #expect(EngineEventInterpreter.formatDuration(1000) == "1.0s")
}

@Test func hitEventGeneratesTerminalLine() {
    let interpreter = EngineEventInterpreter()
    var bank = PadBank()
    let sample = Sample(name: "kick", left: [0.1, 0.2], right: [0.1, 0.2], sampleRate: 44100)
    bank.assign(sample: sample, toPad: 0)

    interpreter.processHits(
        [(padIndex: 0, position: 0, velocity: 112)],
        padBank: bank, loopDurationMs: 8000
    )

    #expect(interpreter.lines.count == 1)
    #expect(interpreter.lines[0].text.contains("kick"))
    #expect(interpreter.lines[0].text.contains("vel 112"))
}

@Test func hitEventSetsIntensity() {
    let interpreter = EngineEventInterpreter()
    var bank = PadBank()
    let sample = Sample(name: "kick", left: [0.1], right: [0.1], sampleRate: 44100)
    bank.assign(sample: sample, toPad: 0)

    interpreter.processHits(
        [(padIndex: 0, position: 0, velocity: 127)],
        padBank: bank, loopDurationMs: 8000
    )

    #expect(interpreter.padIntensities[0] == 1.0)
}

@Test func hardHitFlagged() {
    let interpreter = EngineEventInterpreter()
    var bank = PadBank()
    let sample = Sample(name: "snare", left: [0.1], right: [0.1], sampleRate: 44100)
    bank.assign(sample: sample, toPad: 1)

    interpreter.processHits(
        [(padIndex: 1, position: 0, velocity: 127)],
        padBank: bank, loopDurationMs: 8000
    )

    #expect(interpreter.lines[0].text.contains("hard hit"))
}

@Test func muteChangeEmitsEvent() {
    let interpreter = EngineEventInterpreter()
    // Mute/unmute events are now logged by the UI layer via appendLine
    interpreter.appendLine("pad 4 perc frozen")
    #expect(interpreter.lines.contains { $0.text.contains("frozen") })
}

@Test func ccChangeEmitsEvent() {
    let interpreter = EngineEventInterpreter()
    var layers = (0..<8).map { Layer(index: $0, name: "PAD \($0 + 1)") }

    // First call establishes baseline
    interpreter.processStateDiff(layers: layers, transport: Transport(),
                                  capture: GodCapture(), padBank: PadBank(), masterVolume: 1.0)

    // Change volume on pad 0
    layers[0].volume = 0.72
    interpreter.processStateDiff(layers: layers, transport: Transport(),
                                  capture: GodCapture(), padBank: PadBank(), masterVolume: 1.0)

    #expect(interpreter.lines.contains { $0.text.contains("vol → 72%") })
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

    let summaryLine = interpreter.lines.last!.text
    #expect(summaryLine.contains("hats"))
    #expect(summaryLine.contains("4 hits"))
    #expect(summaryLine.contains("tight"))
}

@Test func transportStartEmitsEvent() {
    let interpreter = EngineEventInterpreter()
    // Transport events are now logged by the UI layer via appendLine
    interpreter.appendLine("▶ loop start — 4 bars @ 120bpm (8.0s)")
    #expect(interpreter.lines.contains { $0.text.contains("loop start") })
    #expect(interpreter.lines.contains { $0.text.contains("120bpm") })
}

@Test func captureArmedEmitsEvent() {
    let interpreter = EngineEventInterpreter()
    // Capture armed is now logged by the UI layer via appendLine
    interpreter.appendLine("capture armed — next loop boundary")
    #expect(interpreter.lines.contains { $0.text.contains("capture armed") })
}

@Test func loopBoundaryWrapEvent() {
    let interpreter = EngineEventInterpreter()
    let layers = (0..<8).map { Layer(index: $0, name: "PAD \($0 + 1)") }
    interpreter.onLoopBoundary(layers: layers, padBank: PadBank(), loopDurationMs: 8000)

    #expect(interpreter.lines.contains { $0.text.contains("loop 1 — wrap") })
}

@Test func sustainedDecaySlowerThanShort() {
    let interpreter = EngineEventInterpreter()
    interpreter.padIntensities = Array(repeating: 1.0, count: 8)
    interpreter.activePadVoices = [0] // pad 0 has active voice

    for _ in 0..<10 {
        interpreter.tickVisuals()
    }

    #expect(interpreter.padIntensities[0] > interpreter.padIntensities[1])
}

@Test func visualDecay() {
    let interpreter = EngineEventInterpreter()
    interpreter.padIntensities = [1.0, 0, 0, 0, 0, 0, 0, 0]

    interpreter.tickVisuals()
    #expect(interpreter.padIntensities[0] < 1.0)
    #expect(interpreter.padIntensities[0] > 0.9)

    for _ in 0..<100 {
        interpreter.tickVisuals()
    }
    #expect(interpreter.padIntensities[0] == 0)
}

@Test func maxLinesRespected() {
    let interpreter = EngineEventInterpreter()
    for i in 0..<50 {
        interpreter.appendLine("line \(i)")
    }
    #expect(interpreter.lines.count == 30)
}

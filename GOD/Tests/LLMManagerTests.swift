import Testing
import Foundation
@testable import GOD

@Test func llmManagerDebounce() async throws {
    let manager = LLMManager(terminalState: TerminalState())

    // Request twice rapidly — second should be debounced
    let snapshot = StateSnapshot(
        bpm: 120, bars: 4, beat: 1,
        playing: true, capture: "idle", channels: []
    )
    manager.requestInference(snapshot: snapshot)
    manager.requestInference(snapshot: snapshot)

    #expect(manager.pendingRequestCount <= 1)
}

@Test func llmManagerModelMissing() {
    let state = TerminalState()
    let manager = LLMManager(terminalState: state)
    manager.start()

    // Should show missing model message
    #expect(state.lines.first?.text.contains("no model loaded") == true)
}

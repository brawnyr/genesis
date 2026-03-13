import Testing
@testable import Genesis

@Test func ringBufferOverflowKeepsNewest() {
    let buffer = MIDIRingBuffer()
    // Fill past capacity (256) — oldest should be dropped
    for i in 0..<300 {
        buffer.write(.noteOn(note: i % 128, velocity: i % 128))
    }
    var events: [MIDIEvent] = []
    buffer.drain { events.append($0) }
    #expect(events.count == 256)

    // Verify we got the NEWEST 256 events (indices 44..299)
    if case .noteOn(_, let vel) = events.last! {
        #expect(vel == 299 % 128)
    } else {
        Issue.record("Expected noteOn")
    }
    if case .noteOn(_, let vel) = events.first! {
        #expect(vel == 44 % 128)
    } else {
        Issue.record("Expected noteOn")
    }
}

@Test func ringBufferMultiDrainCycles() {
    let buffer = MIDIRingBuffer()

    // First write+drain cycle
    buffer.write(.noteOn(note: 36, velocity: 100))
    buffer.write(.cc(number: 74, value: 64))
    var batch1: [MIDIEvent] = []
    buffer.drain { batch1.append($0) }
    #expect(batch1.count == 2)

    // Second drain with no new writes — should be empty
    var batch2: [MIDIEvent] = []
    buffer.drain { batch2.append($0) }
    #expect(batch2.count == 0)

    // Third write+drain cycle
    buffer.write(.noteOff(note: 36))
    var batch3: [MIDIEvent] = []
    buffer.drain { batch3.append($0) }
    #expect(batch3.count == 1)
    if case .noteOff(let note) = batch3[0] {
        #expect(note == 36)
    } else {
        Issue.record("Expected noteOff")
    }
}

import Testing
@testable import GOD

@Test func ringBufferWriteAndDrain() {
    let buffer = MIDIRingBuffer()
    buffer.write(.noteOn(note: 36, velocity: 100))
    buffer.write(.noteOn(note: 37, velocity: 80))

    var events: [MIDIEvent] = []
    buffer.drain { events.append($0) }

    #expect(events.count == 2)
    if case .noteOn(let note, let vel) = events[0] {
        #expect(note == 36)
        #expect(vel == 100)
    } else {
        Issue.record("Expected noteOn")
    }
    if case .noteOn(let note, let vel) = events[1] {
        #expect(note == 37)
        #expect(vel == 80)
    } else {
        Issue.record("Expected noteOn")
    }
}

@Test func ringBufferDrainEmpty() {
    let buffer = MIDIRingBuffer()
    var events: [MIDIEvent] = []
    buffer.drain { events.append($0) }
    #expect(events.count == 0)
}

@Test func ringBufferOverflow() {
    let buffer = MIDIRingBuffer()
    // Fill past capacity (256)
    for i in 0..<300 {
        buffer.write(.noteOn(note: i % 128, velocity: 100))
    }
    var events: [MIDIEvent] = []
    buffer.drain { events.append($0) }
    // Should get 256 (capacity), oldest dropped
    #expect(events.count == 256)
}

@Test func ringBufferNoteOff() {
    let buffer = MIDIRingBuffer()
    buffer.write(.noteOff(note: 36))
    var events: [MIDIEvent] = []
    buffer.drain { events.append($0) }
    #expect(events.count == 1)
    if case .noteOff(let note) = events[0] {
        #expect(note == 36)
    } else {
        Issue.record("Expected noteOff")
    }
}

@Test func ringBufferCC() {
    let buffer = MIDIRingBuffer()
    buffer.write(.cc(number: 14, value: 64))
    var events: [MIDIEvent] = []
    buffer.drain { events.append($0) }
    #expect(events.count == 1)
    if case .cc(let num, let val) = events[0] {
        #expect(num == 14)
        #expect(val == 64)
    } else {
        Issue.record("Expected cc")
    }
}

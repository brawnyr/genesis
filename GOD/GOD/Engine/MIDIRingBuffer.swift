import Foundation

enum MIDIEvent {
    case noteOn(note: Int, velocity: Int)
    case noteOff(note: Int)
    case cc(number: Int, value: Int)
}

struct MIDIRingBuffer {
    private var buffer = [MIDIEvent?](repeating: nil, count: 256)
    private var writeIndex: Int = 0
    private var readIndex: Int = 0

    mutating func write(_ event: MIDIEvent) {
        buffer[writeIndex % 256] = event
        writeIndex += 1
        // If we've lapped the reader, advance reader (drop oldest)
        if writeIndex - readIndex > 256 {
            readIndex = writeIndex - 256
        }
    }

    mutating func drain(_ handler: (MIDIEvent) -> Void) {
        while readIndex < writeIndex {
            if let event = buffer[readIndex % 256] {
                handler(event)
            }
            readIndex += 1
        }
    }
}

import Foundation
import Darwin

enum MIDIEvent {
    case noteOn(note: Int, velocity: Int)
    case noteOff(note: Int)
    case cc(number: Int, value: Int)
}

/// Single-producer (MIDI thread) single-consumer (audio thread) ring buffer.
/// Uses OSMemoryBarrier() to ensure correct visibility of writes across threads
/// on ARM64 (Apple Silicon) without needing locks.
final class MIDIRingBuffer {
    private static let capacity = 256
    private static let mask = capacity - 1

    private var buffer = [MIDIEvent?](repeating: nil, count: capacity)
    private var _writeIndex: UInt64 = 0
    private var _readIndex: UInt64 = 0

    func write(_ event: MIDIEvent) {
        let wi = _writeIndex
        buffer[Int(wi) & Self.mask] = event
        OSMemoryBarrier()
        _writeIndex = wi &+ 1
        if _writeIndex &- _readIndex > UInt64(Self.capacity) {
            _readIndex = _writeIndex &- UInt64(Self.capacity)
        }
    }

    func drain(_ handler: (MIDIEvent) -> Void) {
        OSMemoryBarrier()
        while _readIndex < _writeIndex {
            if let event = buffer[Int(_readIndex) & Self.mask] {
                handler(event)
            }
            _readIndex &+= 1
        }
    }
}

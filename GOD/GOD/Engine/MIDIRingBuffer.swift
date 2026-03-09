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
    private var buffer = [MIDIEvent?](repeating: nil, count: 256)
    private var _writeIndex: Int = 0
    private var _readIndex: Int = 0

    func write(_ event: MIDIEvent) {
        let wi = _writeIndex
        buffer[wi % 256] = event
        // Memory barrier: ensure buffer write is visible before index update
        OSMemoryBarrier()
        _writeIndex = wi + 1
        if _writeIndex - _readIndex > 256 {
            _readIndex = _writeIndex - 256
        }
    }

    func drain(_ handler: (MIDIEvent) -> Void) {
        // Memory barrier: ensure we see latest _writeIndex
        OSMemoryBarrier()
        while _readIndex < _writeIndex {
            if let event = buffer[_readIndex % 256] {
                handler(event)
            }
            _readIndex += 1
        }
    }
}

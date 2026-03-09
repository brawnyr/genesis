# MIDI System Fixes Design

## Problem

The MIDI system in GOD has four issues:

1. **Thread safety** — `onPadHit` dispatches to main thread but writes audio-thread state (`voices`, `audioLayers`), causing data races with `processBlock`
2. **No Note Off handling** — only Note On is parsed; needed for future hold-mode pads
3. **No CC/knob support** — MiniLab 3 knobs unused; wanted for per-channel volume
4. **No MIDI tests** — zero test coverage for MIDI input path

## Design

### 1. Lock-Free Ring Buffer + Thread Safety Fix

**New types:**

```swift
enum MIDIEvent {
    case noteOn(note: Int, velocity: Int)
    case noteOff(note: Int)
    case cc(number: Int, value: Int)
}
```

`MIDIRingBuffer` — fixed-size (256 slots), single-producer/single-consumer, lock-free using atomic read/write indices.

**Flow:**
1. `MIDIManager.handleMIDIEvents` parses raw MIDI → writes `MIDIEvent` into ring buffer (no DispatchQueue.main.async)
2. `GodEngine.processBlock` drains ring buffer at top of each render cycle
3. `onPadHit` becomes audio-thread-only — no main thread dispatch for hit logic
4. UI feedback (trigger flash) posted to main via existing throttled UI update at bottom of `processBlock`

Eliminates all data races on `voices`, `audioLayers`, `audioPosition`.

### 2. Note Off Support

**Pad gains:**
```swift
var isOneShot: Bool = true  // default one-shot, toggleable later
```

**Voice gains:**
```swift
var padIndex: Int  // which pad triggered this voice
```

**Note Off in processBlock** (after draining ring buffer):
- Look up pad index from note, check `isOneShot`
- If one-shot: ignore
- If hold mode: mark matching voices for that pad as done

Side benefit: signal level detection matches by `padIndex` instead of sample name.

### 3. CC Knob → Per-Channel Volume

**MiniLab 3 default:** Knobs 1-8 send CC 14-21.

**Layer gains:**
```swift
var volume: Float = 1.0  // 0.0 - 1.0
```

**CC handling in processBlock:**
- CC 14-21 → layer index 0-7
- Set `audioLayers[index].volume = Float(value) / 127.0`
- Sync to UI layer on throttled update

**Voice mixing** applies layer volume via `audioLayers[padIndex].volume`.

### 4. MIDI Tests

New file `Tests/MIDITests.swift`:
- Ring buffer: write/drain FIFO order, overflow behavior
- Note mapping: 36-43 → pad 0-7, out-of-range ignored
- CC mapping: CC 14-21 → layer volume 0-7, unmapped ignored
- Note Off: one-shot ignores, hold-mode stops voice
- `onPadHit` integration: hit added to layer, voice spawned with correct padIndex/velocity

No CoreMIDI mocking — tests exercise engine logic directly.

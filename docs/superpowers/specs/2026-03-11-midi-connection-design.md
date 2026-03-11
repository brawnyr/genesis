# MIDI Connection Fix — Design Spec

## Problem

MIDI controller (Arturia MiniLab 3) is completely dead when GOD launches. No connection, no feedback, no sound from pads. The controller works fine in FL Studio.

## Root Cause

Every CoreMIDI API call in `MIDIManager.swift` ignores its `OSStatus` return value. If `MIDIClientCreateWithBlock` fails, `midiClient` stays 0, port creation fails, `MIDIPortConnectSource` connects to nothing — all silently. Additionally, the MIDI ring buffer only drains during playback (`processBlock` bails on `guard audioIsPlaying`), so even if MIDI were connected, pads wouldn't work until you hit play.

## Changes

### 1. MIDIManager.swift — Rewrite

**Error handling:**
- Check `OSStatus` on `MIDIClientCreateWithBlock`, `MIDIInputPortCreateWithProtocol`, and `MIDIPortConnectSource`
- Log failures to interpreter with descriptive messages

**Device connection:**
- Connect to all available MIDI sources (not just MiniLab-named ones)
- Log each successful connection: `midi → arturia minilab 3 connected`
- Log when no sources found: `midi → no devices found`

**Hot-plug/unplug:**
- Handle `.msgObjectAdded` — reconnect new devices
- Handle `.msgObjectRemoved` — log disconnection
- Handle `.msgSetupChanged` as catch-all — re-enumerate and reconnect

**UMP parsing:**
- Verify message type field (bits 31-28 == 0x2) before parsing channel voice messages
- Prevents misinterpreting system messages or other UMP types

**MIDI event logging:**
- Log note on: `pad 3 hit · note 38 · vel 92`
- Log CC: `cc 14 · value 64`
- All logging goes through the existing `EngineEventInterpreter`

**Interpreter access:**
- Add `var interpreter: EngineEventInterpreter?` property
- MIDIManager logs connection events directly
- MIDI event logging happens in GodEngine when events are drained (audio thread → main thread via existing pending mechanism)

### 2. GodEngine.swift — Always Drain MIDI

**Current behavior:** `processBlock` returns empty buffers immediately when `audioIsPlaying == false`. Ring buffer never drains. MIDI events pile up and are lost.

**New behavior:**
- Always drain the MIDI ring buffer, regardless of transport state
- When transport is stopped:
  - `noteOn` → trigger a voice (audition the sound), do NOT record hit to layer
  - `noteOff` → kill voice if not one-shot
  - `cc` → apply to active layer as usual
- When transport is playing:
  - Existing behavior unchanged (trigger voice + record hit)
- Move MIDI drain and voice mixing outside the `guard audioIsPlaying` early return
- Loop-based hit replay and metronome remain gated on `audioIsPlaying`

### 3. GODApp.swift — Wire Interpreter to MIDIManager

- After creating MIDIManager, set `midi.interpreter = interpreter`
- Ensures connection/disconnection events appear in the terminal log on startup

## Files Modified

| File | Change |
|------|--------|
| `GOD/Engine/MIDIManager.swift` | Full rewrite — error handling, logging, hot-plug, UMP validation |
| `GOD/Engine/GodEngine.swift` | Drain MIDI when stopped, audition pads without recording |
| `GOD/GODApp.swift` | Pass interpreter to MIDIManager |

## Files NOT Modified

- `MIDIRingBuffer.swift` — works correctly as-is
- `MIDIEvent` enum — no new event types needed for this change
- UI views — no new UI elements, all feedback through existing terminal log
- Entitlements — no MIDI entitlement needed on macOS (CoreMIDI is not TCC-gated)
- `AudioManager.swift` — no changes needed

## Testing

- Plug in MiniLab, launch GOD → should see `midi → arturia minilab 3 connected` in log
- Hit pads with transport stopped → should hear sound and see `pad X hit · note XX · vel XX`
- Hit pads with transport playing → same, plus hits recorded to layer
- Unplug MiniLab → should see disconnection message
- Replug MiniLab → should reconnect and log
- Launch with no MIDI device → should see `midi → no devices found`

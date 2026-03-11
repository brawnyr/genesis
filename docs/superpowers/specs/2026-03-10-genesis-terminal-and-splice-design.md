# Genesis Terminal & Splice Integration Design

## Overview

Two features that reshape GOD's interface and workflow:

1. **Splice sample folders** — 8 curated folders that auto-load into pads on launch
2. **Genesis Terminal** — a right-panel terminal view with an LLM (llama) providing real-time session commentary, plus a procedural art system (separate spec)

The UI becomes a split view: instrument controls on the left, Genesis Terminal on the right, unified under the Anthropic/Claude aesthetic.

---

## 1. Splice Sample Folders

### Folder Structure

8 folders at `~/Splice/sounds/`:

| Pad | Folder |
|-----|--------|
| 1   | `kicks` |
| 2   | `snares` |
| 3   | `hats` |
| 4   | `perc` |
| 5   | `bass` |
| 6   | `keys` |
| 7   | `vox` |
| 8   | `fx` |

### Behavior

- On app launch, scan each folder and load the first audio file (alphabetical) into the corresponding pad
- If a folder is empty or missing, pad stays unloaded — can still load manually via setup
- Existing manual load (SetupView) still works as override
- No hot-reloading — samples load at launch only

### Loading Sequence

1. `PadBank.loadConfig()` runs first — loads `~/.god/pads.json` if it exists
2. For each pad that has NO sample loaded after step 1, scan the corresponding Splice folder
3. If a Splice folder has an audio file, load the first one (alphabetical) into that pad
4. Pads with existing pads.json entries are never overwritten by Splice scan
5. After all pads resolve, `PadBank.save()` persists the final state

This means pads.json acts as sticky overrides — once you manually load a sample, it stays until you clear it.

---

## 2. UI Redesign — Split View

### Layout

```
┌──────────────────────────┬─────────────────────────────┐
│                          │                             │
│   INSTRUMENT (left)      │   GENESIS TERMINAL (right)  │
│                          │                             │
│   Transport              │   LLM commentary stream     │
│   8 channel rows         │   (procedural art — future) │
│   Capture indicator      │                             │
│                          │                             │
├──────────────────────────┴─────────────────────────────┤
│   Tips line                                            │
└────────────────────────────────────────────────────────┘
```

### Design Principles

- One window, one surface — no hard divider, just spacing
- Same dark background (`#1a1917`), same monospace type throughout
- Left panel is the instrument: transport, channels, capture — tightened from current layout
- Right panel is the Genesis Terminal: scrolling text, monospace, terminal feel
- Tips line stays at the bottom, spanning full width — unchanged
- The two halves feel integrated, like one cohesive tool

### Window Size

- Current: 600x700
- New: wider to accommodate split — ~1000x700
- Fixed 50/50 split ratio via `HStack` with equal-width frames
- Minimum window width: 800 (panels compress proportionally)
- Keyboard shortcut `T` toggles terminal panel visibility (instrument goes full-width when hidden)

---

## 3. Genesis Terminal — LLM Diagnostic Feed

### What It Is

A local LLM (llama model via `llama.cpp` or MLX) observes engine state and produces real-time commentary about the session. Claude-toned — informative, accurate, loose, conversational. Like a studio partner watching you play.

### Voice & Tone

- Accurate and useful — it really does tell you what's going on
- Claude personality — warm, not stiff, not a log file
- Short lines, but not terse to the point of being cold
- Conversational, like someone in the room

Examples:
```
that pad on ch3 is getting chopped — 1.2s past the loop edge
kick is sitting right on the one, clean
you're filtering ch5 pretty hard, 340Hz LP
ch3 and ch7 are bumping into each other around 400Hz
recording armed — picks up next boundary
nice, the snare just locked in with the kick
```

### Engine State Inputs

The LLM receives a structured snapshot of engine state:

- **Pads**: which are loaded, sample names, sample durations
- **Layers**: hit positions, hit count, mute state
- **Effects**: volume, pan, HP/LP cutoff per layer
- **Transport**: BPM, bar count, playing/stopped, current beat
- **Sample vs loop**: sample duration relative to loop length — detects truncation, overhang, perfect fit
- **Capture**: armed/recording/idle
- **Signal levels**: per-channel peaks

### Update Cadence

- Not every frame — triggered by meaningful state changes
- Events that trigger commentary: new hit recorded, parameter change (CC), loop boundary crossed, sample truncation detected, capture state change, mute/unmute, layer cleared
- Roughly 2-5 messages per loop cycle depending on activity
- Quiet when nothing is changing — doesn't fill silence with noise

### Model

- Local llama model via `llama-server` (HTTP API on port 8421, `/v1/chat/completions`)
- Starts on app launch, stays alive for the session, killed on app quit
- If model binary or weights are missing, terminal shows a static message: `"no model loaded — drop a gguf into ~/.god/models/"`
- If the subprocess crashes, terminal shows `"model disconnected"` and stops requesting — no auto-restart to avoid CPU churn

### State Snapshot Format

Sent to the model as a structured prompt on each inference request:

```json
{
  "bpm": 120,
  "bars": 4,
  "beat": 3,
  "playing": true,
  "capture": "idle",
  "channels": [
    {
      "ch": 1,
      "sample": "kick_heavy.wav",
      "sample_duration_ms": 450,
      "loop_duration_ms": 8000,
      "hits": 4,
      "muted": false,
      "volume": 0.8,
      "pan": 0.5,
      "hp_hz": 20,
      "lp_hz": 20000,
      "peak_db": -12.3,
      "truncated": false
    }
  ]
}
```

- `sample_duration_ms` and `loop_duration_ms` enable the model to detect truncation, overhang, and fit
- `peak_db` is a rolling peak over the last inference interval (not instantaneous)
- `truncated` is pre-computed by the engine: `true` if sample_duration > loop_duration`

### Resource Management

- LLM runs on a background thread, never on the audio render thread
- Inference requests are debounced: minimum 2 seconds between requests, events coalesce
- If inference takes longer than 3 seconds, the pending request is dropped (not queued)
- Model should be small enough to leave headroom for real-time audio (target: <2GB RAM, inference on CPU/ANE)
- Audio engine has absolute priority — if the system is under load, LLM requests are silently skipped

### Terminal Rendering

- Monospace text, scrolling upward (newest at bottom)
- Dim older messages, brighter recent ones — opacity 1.0 for newest, fading linearly to 0.3 for oldest visible line
- Claude blue (`#6283e2`) for key info, default text color for commentary
- No timestamps — the scroll itself is the timeline
- Scrollback buffer: ~50 lines visible, older messages drop off

---

## 4. Procedural Art System

**Deferred to separate brainstorm session.** Will share the Genesis Terminal pane — art and text coexist in the same right panel. Design TBD.

Initial implementation should have the terminal text fill the full right panel. The procedural art spec will define how the panel splits between art and text.

## 5. Prerequisites

- `Sample` model needs a `durationMs` computed property (frame count / sample rate * 1000)
- `GodEngine` needs a `loopDurationMs` computed property from transport
- `GodEngine` needs a method to generate the state snapshot JSON for the LLM
- `llama-server` binary (from `llama.cpp`, install via `brew install llama.cpp`) and a `.gguf` model file at `~/.god/models/`

## 6. Testing

- Splice loading: unit test that `PadBank` correctly resolves Splice folders vs pads.json priority
- State snapshot: unit test that `GodEngine.stateSnapshot()` produces valid JSON with correct truncation detection
- Event debounce: unit test that rapid CC changes coalesce into a single inference request
- LLM subprocess: integration test that verifies start/stop lifecycle and crash recovery message

---

## 7. Out of Scope

- Hot-reloading samples from Splice folders (launch only)
- Waveform display (may come with procedural art)
- Changes to the tips system
- Changes to MIDI mapping or effects routing
- Cloud/API-based LLM (using local llama only)

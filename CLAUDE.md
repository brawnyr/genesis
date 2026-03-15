# Genesis

A custom loop-based music instrument for macOS. Built in Swift/SwiftUI. You play pads via MIDI (Arturia MiniLab 3), record hits into a looping timeline, layer sounds, shape them with filters and reverb, and bounce to disk. Not a DAW — a live instrument for making beats.

## Vision

Genesis is about the loop. Playing what you feel. Things coming in, going out, transforming, staying the same. Every visual and data point serves the act of moving you. We're always iterating.

## Design System — Codename: First Light

Full spec in `GENESIS_FIRST_LIGHT.md`. Visual mockup in `genesis-design-vision.jsx`.

**Core rules:**
- **Midnight canvas** — backgrounds are deep navy-black (#0B1120), never green, never brown
- **White heat** — hero numbers burn true white (#F8FAFC), not silver, not cream
- **Electric blue accent** (#3B82F6) — section titles, dividers, oracle, system identity
- **17pt floor** — nothing in the app renders below 17pt. If text doesn't fit, make the container bigger, never the font smaller
- **Every zone titled** — MASTER, TERMINAL, HOTKEYS, PAD_SELECT, INSPECT, BROWSER all get labeled headers in electric blue 20pt semibold
- **Full spectrum pads** — 8 distinct colors spanning warm AND cool (orange, gold, sky blue, green, electric blue, violet, rose, mint)
- **No limiters, no soft clipping** — raw float output straight to DAC

## Architecture

Two-thread model:
- **Audio thread** (real-time, AVAudioEngine callback) — runs `processBlock` every 128 frames (~2.9ms). Owns `AudioState`, `VoicePool`, output buffers. Protected by `os_unfair_lock` held briefly for state reads, released before heavy rendering.
- **Main thread** (SwiftUI) — owns `@Published` properties. Synced from audio thread via `DispatchQueue.main.async` at ~30Hz through `UISnapshot`.

**MIDI path:** MiniLab 3 → CoreMIDI callback → lock-free SPSC ring buffer (256 slots) → drained in processBlock.

**MPC-style loop boundary:** Voices ring through the wrap naturally. No output-buffer crossfade, no blanket voice kill. Per-voice declick (44-sample fade) handles choke/retrigger pops. Beat 1 hits at full force.

## Audio Thread Rules

- **Zero heap allocations** in processBlock — pre-allocated buffers, in-place iteration, swap instead of copy
- **No Array concatenation** inside the lock — iterate hit arrays directly with binary search
- **Per-voice declick** on kill (44 samples ~1ms fade) — never hard-cut a playing waveform
- **Voice pool:** 32 slots, first-available allocation. If full, note is dropped silently.
- **Cached biquad coefficients** — only recalculate when cutoff changes
- **Unsafe pointer access** in Voice.fill inner loop — eliminates Swift bounds checks

## Key Bindings

| Key | Action |
|-----|--------|
| Space | Play/stop |
| Escape | Stop |
| R | Toggle record arm (loop plays without recording when off) |
| T | Toggle looper on active pad |
| Shift+T | Open sample browser |
| ←→ or A/D | Navigate pads |
| W/S or ↑↓ | Browse samples (in browser mode) |
| B | BPM mode (W/S scroll presets, type digits) |
| Y | Cycle bar count (1→2→4) |
| Q | Mute active pad |
| Shift+Q | Master mute |
| Cmd+Shift+Q | Mute all |
| X | Toggle choke |
| V | Toggle velocity mode (full/pressure) |
| M | Toggle metronome |
| C | Clear active pad |
| Z | Undo clear |
| G | Bounce to disk (start/stop WAV capture) |
| O | Toggle oracle (AI session observer) |
| Numpad 0-9 | Set pad volume (0=0%, 9=100%) |

## MIDI CC Mapping (MiniLab 3)

| CC | Control | Function |
|----|---------|----------|
| 82 | Fader 1 | Master volume |
| 83 | Fader 2 | Pad volume |
| 17 | Fader 4 | Kill all voices (panic) |
| 85 | — | Metronome volume |
| 74 | Knob 1 | Reverb send |
| 71 | Knob 2 | Pan |
| 76 | Knob 3 | HP cutoff |
| 77 | Knob 4 | LP cutoff |
| 18 | Knob 5 | Swing |
| 114 | Browse encoder | Pad select (relative) |

## File Structure

```
Genesis/Genesis/
├── Engine/
│   ├── GenesisEngine.swift          — main engine, UI/audio state, transport
│   ├── GenesisEngine+ProcessBlock.swift — audio render callback, MIDI drain, hit scan
│   ├── VoicePool.swift              — Voice struct (fill, declick), VoicePool (allocate, kill)
│   ├── VoiceMixer.swift             — multi-voice mixing, reverb send routing
│   ├── SwingMath.swift              — swing timing calculations
│   ├── AudioManager.swift           — AVAudioEngine setup, 128-frame buffer
│   ├── MIDIManager.swift            — CoreMIDI device handling
│   ├── MIDIRingBuffer.swift         — lock-free SPSC queue (256 slots)
│   ├── ReverbProcessor.swift        — Schroeder stereo reverb
│   ├── EngineEventInterpreter.swift — terminal logging, state diffing
│   └── SessionOracle.swift          — AI observer via Ollama/mistral
├── Models/
│   ├── Layer.swift                  — per-pad state (hits, volume, pan, filters, swing)
│   ├── Sample.swift                 — audio file loading with resampling
│   ├── Transport.swift              — BPM, bar count, loop length
│   ├── Pad.swift                    — pad definitions, PadBank, Splice folder mapping
│   ├── Biquad.swift                 — filter coefficients and processing
│   ├── Metronome.swift              — click generation (4 distinct beats)
│   └── GenesisCapture.swift         — WAV recording/export
├── Views/
│   ├── Theme.swift                  — First Light design system
│   ├── ContentView.swift            — main layout, hotkey HUD
│   ├── ContentView+KeyHandlers.swift — keyboard input handling
│   ├── GHUD.swift                   — master volume/dB display
│   ├── BeatTrackerHUD.swift         — floating beat position overlay
│   ├── PadSelect.swift              — 8-pad strip with volumes + effects
│   ├── PadInspectPanel.swift        — right sidebar inspector
│   ├── SampleBrowserView.swift      — file browser
│   ├── TerminalTextLayer.swift      — scrolling log display
│   └── Theme.swift                  — colors, fonts, design tokens
└── Tests/                           — 56 tests covering engine, voice, filters, swing, MIDI
```

## Defaults

- Velocity mode: full (all hits at 127)
- Metronome: on, volume 25%
- Pad volume: 25% (-12dB headroom)
- Choke: on (retrigger kills previous voice)
- Sample rate: 44100Hz
- Buffer size: 128 frames (~2.9ms latency)
- Samples: loaded from ~/Splice/sounds/ (8 subfolders)
- Recordings: saved to ~/recordings/
- Config: ~/.genesis/ (master.txt, pads.json)

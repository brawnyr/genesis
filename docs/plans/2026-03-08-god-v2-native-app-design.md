# GOD v2 — Native macOS App Design

## Overview

Rewrite GOD from a Python/Flask/HTML stack to a pure SwiftUI + CoreAudio + CoreMIDI native macOS app. Single process, single binary, no web layer.

GOD is a loop-stacking instrument. You set a BPM and bar count, hit play, and a fixed loop plays forever. You hit pads on a MiniLab 3 to trigger samples — each hit gets recorded into the loop at its position. Each pad is its own layer. You mute/unmute/clear layers to shape the beat. GOD capture records the master output for as long as you want.

## Architecture

Single-process SwiftUI app with three layers:

1. **SwiftUI View Layer** — UI rendering, driven by published state (~60fps)
2. **GodEngine (ObservableObject)** — central state: BPM, layers, transport, capture
3. **CoreAudio render callback + CoreMIDI input** — real-time audio mixing and MIDI input

No polling, no IPC, no web stack. SwiftUI observes GodEngine's `@Published` properties and re-renders automatically. CoreAudio and CoreMIDI use callbacks.

## Data Model

- **Transport** — BPM (integer), bar count (1/2/4), current position (frames), playing flag
- **Pad** — MIDI note mapping (notes 36-43), loaded Sample (audio buffer), display name
- **Layer** — one per pad (8 total), array of Hits, mute flag
- **Hit** — position in loop (frame offset) + velocity (0-127)
- **Voice** — currently playing sample instance (position, volume). Fire-and-forget.
- **GodCapture** — state machine (idle → armed → recording), buffer accumulator, WAV writer
- **Metronome** — on/off, procedural click generation at beat boundaries

## Audio Engine

- AVAudioEngine with manual render tap on output node
- 44.1kHz, mono, buffer size 256-512 frames (~6-12ms latency)

Render loop (~86 times/sec at 512 frames):
1. Calculate current position in loop
2. For each unmuted layer, check if any hits fall in this buffer window
3. Trigger voices for hits that land, mix sample audio into output
4. Advance transport, wrap at loop boundary
5. If GOD capture active, copy output to capture accumulator
6. If metronome on, mix click at beat boundaries

Loop length = `(bars × 4 beats) × (60.0 / BPM) × sampleRate`

Voices are additive — multiple can play simultaneously. They play to completion and are removed.

## MIDI Integration

- CoreMIDI client + input port, auto-detect MiniLab 3 by name
- Hot-plug support via device connect/disconnect notifications
- Pads 1-8 mapped to MIDI notes 36-43
- On note-on: record Hit at current transport position into that pad's layer
- Velocity preserved for mixing

## UI Design

MOMENT-inspired aesthetic:
- Dark background (#1a1917), JetBrains Mono throughout
- Warm muted palette: orange accent (#da7b4a), green (#5faa6e), red (#d4564e), amber (#d4a24e)
- Minimal chrome, no toolbar clutter

Layout — single window, vertical flow:

```
┌──────────────────────────────────────────┐
│  G O D                                   │  animated title
│                                          │
│  ▶ 120 BPM  ·  4 BARS  ·  ♩ ON         │  transport status
│                                          │
│  ████████████░░░░░░░░░░░░░░░░░░░░░░░░░  │  loop progress bar
│  1 · · · 2 · · · 3 · · · 4 · · ·       │  beat markers
│                                          │
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐│
│  │1 │ │2 │ │3 │ │4 │ │5 │ │6 │ │7 │ │8 ││  pads (light up on hit)
│  └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘│
│  KICK  SNR  HAT  CLP  PRC  SH1  SH2  FX │  sample names
│                                          │
│  1 KICK  ▶ ████░░░░  ·····●··●··●··●··  │  layers with hit viz
│  2 SNARE ▶ ███░░░░░  ··········●·····●·  │
│  3 HAT   ■ ████████  ··●·●·●·●·●·●·●·●  │  muted = dimmed
│                                          │
│  ● GOD                                   │  capture indicator
│                                          │
│  "ctrl+r reverse-searches your history"  │
│                               — claude   │  typewriter tip
│                                          │
│  > _                                     │  command input
└──────────────────────────────────────────┘
```

Key behaviors:
- Pads flash on hit (brief color pulse, fades)
- Layer rows show dot-pattern of hit positions in the loop
- Loop progress bar animates smoothly
- Tips cycle with typewriter effect, shuffle-deck (no repeats until all shown)
- GOD indicator pulses red when capturing
- Muted layers dimmed/struck-through

## Keyboard Shortcuts

- `Space` — play/stop
- `G` — toggle GOD capture
- `M` — toggle metronome
- `↑↓` — BPM ±1
- `1-8` — toggle mute on layer 1-8
- `Shift+1-8` — clear layer 1-8
- `Esc` — stop all, reset

## Command Input

Simple text commands parsed by splitting on space:
- `play` / `stop`
- `bpm 140`
- `god`
- `clear 3`
- `mute 2` / `unmute 2`

## Sample Loading

- Settings/setup view for assigning samples to the 8 pads
- Browse filesystem or drag-and-drop audio files (WAV/MP3/FLAC)
- Assignments persist to `~/.god/pads.json`
- Last kit auto-loads on launch
- No sample browsing during performance — set up kit, then play

## What's NOT in v2

- No piano roll / note editor
- No song arrangement / multiple sections
- No effects / pitch / time-stretch
- No vocals (future scope)
- No cross-platform (macOS only)
- No granular undo (clear entire layer instead)

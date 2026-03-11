# GOD — Genesis On Disk

Native macOS loop-stacking instrument.

## What This Is
A SwiftUI app for live loop-stacking driven by an Arturia MiniLab 3. Not a DAW. A performance instrument. Play pads, stack layers, capture output.

## Core Workflow
- Set tempo (whole numbers) and bar length (1, 2, or 4 bars)
- Play MiniLab 3 pads — samples trigger and record into their layer
- Each pad = one layer. Stack layers, mute/unmute/clear to shape the beat
- **GOD capture**: arms, then records master output on next loop boundary
- Keyboard shortcuts for fast control during performance

## Tech Stack
- Swift, SwiftUI
- CoreAudio (AVAudioEngine) for audio
- CoreMIDI for MIDI input
- macOS 14+

## Project Structure
- `GOD/GOD/Models/` — Transport, Sample, Voice, Layer, Pad, Metronome, GodCapture, Tips
- `GOD/GOD/Engine/` — GodEngine, AudioManager, MIDIManager
- `GOD/GOD/Views/` — SwiftUI views (Theme, Transport, LoopBar, PadGrid, LayerList, Tips, etc.)
- `GOD/Tests/` — Swift Testing unit tests

## Current State
- **Active codebase: Swift only** — `GOD/` directory is the live project
- `src/god/` and `tests/` are the **legacy Python v1 prototype** — do NOT modify or review
- Branch: `god-v2-swift`
- 12 Swift test files in `GOD/Tests/`
- Per-layer effects (biquad filters, pan, volume, CC routing) just landed
- Design docs and plans live in `docs/`

## Splice Integration
GOD pairs well with [Splice](https://splice.com) — browse and download sounds from Splice, and they auto-sort into ready-to-play category folders for your pads.
- `tools/splice_sorter.py` — watches `~/splice/sounds/packs/` and sorts downloads into `kicks/`, `snares/`, `hats/`, `bass/`, `perc/`, `vox/`, `keys/`, `fx/`
- After cloning: `python3 tools/splice_sorter.py --install` to activate the background watcher
- `--uninstall` to remove, `--dry-run` to preview

## Commands
- `god` alias: `cd ~/god/GOD && swift build && .build/arm64-apple-macosx/debug/GOD`
- Tests: `cd ~/god/GOD && swift test`

## Principles
- Light and fast
- Performance-first — you play, it records
- **Anthropic/Claude aesthetic** — dark backgrounds, monospace type, soft glows, muted earth tones with Claude blue (`#6283e2`) and orange (`#da7b4a`) accents, minimal chrome, calm and intentional. All visual/UI decisions should feel like they belong in the Claude product family.
- No bloat, no DAW features you won't use

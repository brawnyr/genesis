# GOD — Genesis On Disk

A playground for making music. Not a DAW — a personal instrument.

## Codebase Cache
**Read `CODEBASE.md` before reading any source files.** It contains complete type signatures, architecture, and patterns for every file in the project. Only open individual `.swift` files when you need to make edits or see exact implementation details. This saves significant context window space. If a task requires reading every file in the project, that's fine — the cache is a shortcut, not a restriction.

**MANDATORY**: After editing, creating, or deleting any `.swift` file, you MUST update `CODEBASE.md` to reflect the changes before committing. Update only the sections that changed — don't regenerate the whole file. This keeps the cache accurate across sessions.

## What This Is
A live loop-stacking instrument driven by an Arturia MiniLab 3. Not a DAW. Play pads, stack layers, capture output.

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
- `GOD/GOD/Models/` — Transport, Sample, Voice, Layer, Pad, Biquad, Metronome, GodCapture
- `GOD/GOD/Engine/` — GodEngine (+ ProcessBlock extension, VoiceMixer), AudioManager, MIDIManager, MIDIRingBuffer, BPMDetector, EngineEventInterpreter
- `GOD/GOD/Views/` — Theme, CanvasView (+ GodTitleLayer, PadVisualsLayer, TerminalTextLayer), PadStripView (+ PadCell, PadCellOverlay, MarqueeText), CCPanelView, SampleBrowserView, TransportView, KeyReferenceOverlay
- `GOD/GOD/` — ContentView (+ KeyHandlers extension), GODApp
- `GOD/Tests/` — Swift Testing unit tests (13 files)
- `tools/` — Splice download sorter (optional)
- `docs/` — Design specs and implementation plans

## Splice Integration
GOD pairs well with [Splice](https://splice.com) — browse and download sounds from Splice, and they auto-sort into ready-to-play category folders for your pads.
- `tools/splice_sorter.py` — watches `~/splice/sounds/packs/` and sorts downloads into `kicks/`, `snares/`, `hats/`, `bass/`, `perc/`, `vox/`, `keys/`, `fx/`
- After cloning: `python3 tools/splice_sorter.py --install` to activate the background watcher
- `--uninstall` to remove, `--dry-run` to preview

## Commands
- `god` alias: `cd ~/god/GOD && swift build && .build/arm64-apple-macosx/debug/GOD`
- Build only: `cd ~/god/GOD && swift build`
- Tests: `cd ~/god/GOD && swift test`

## Principles
- Light and fast
- Performance-first — you play, it records
- **Anthropic/Claude aesthetic** — dark backgrounds, monospace type, soft glows, muted earth tones with Claude blue (`#6283e2`) and orange (`#da7b4a`) accents, minimal chrome, calm and intentional. All visual/UI decisions should feel like they belong in the Claude product family.
- No bloat, no DAW features you won't use

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

## Principles
- Light and fast
- Performance-first — you play, it records
- MOMENT-inspired aesthetic: dark, monospace, animated, Claude tips
- No bloat, no DAW features you won't use

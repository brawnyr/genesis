# GOD — Genesis On Disk

Terminal-based loop production process.

## What This Is
A TUI loop-stacking instrument driven by an Arturia MiniLab 3. Not a DAW. A process. Play pads, stack patterns, capture output.

## Core Workflow
- Set tempo (whole numbers) and bar length (1, 2, or 4 bars)
- Play MiniLab 3 pads — samples trigger and loop
- Stack patterns: each layer loops, you keep adding on top
- Patterns have on/off, volume, color/symbol-coded status
- **GOD button**: arms capture — on next loop pass, records all output to disk
- Master volume control

## Visual Language
- Colors and symbols indicate pattern state (playing, muted, etc.)
- Clean, modern TUI — no clutter, no note grids, no piano roll
- You play it, you hear it, you feel it

## Tech Stack
- Python
- TUI: `textual`
- MIDI: `mido` + `python-rtmidi`
- Audio: `sounddevice`
- Keep it light

## Principles
- Light and fast
- Performance-first — you play, it records
- Iterate constantly
- No bloat, no DAW features you won't use

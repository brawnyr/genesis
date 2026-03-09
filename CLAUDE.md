# cbeat

Terminal-based MPC-style beat production tool.

## What This Is
A TUI DAW focused on pad-based sample triggering, MPC-style loop recording, and sample manipulation. Built for a fast, hands-on workflow using an Arturia MiniLab 3 as the primary input.

## Core Concepts
- **TUI dashboard** with panels: pad grid, step sequencer, mixer, waveform display
- **MiniLab 3** pads are the primary instrument input (MIDI)
- **MPC workflow**: set bar length, hit record, play pads, quantize, loop
- **Sample manipulation**: chop, pitch shift, time stretch, effects
- **Splice** is the primary sample source

## Tech Stack
- Python
- TUI: `textual` or `rich`
- MIDI: `mido` + `python-rtmidi`
- Audio: `sounddevice`, `pedalboard` (effects)
- Keep it lightweight

## Principles
- Keep it light — minimal dependencies, fast startup
- Build for the workflow, not features
- MiniLab 3 is always the primary input
- Terminal-first, may become a standalone app later

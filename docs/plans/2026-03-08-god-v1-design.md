# GOD v1 Design — Genesis On Disk

## What GOD Is
A terminal-based loop-stacking instrument. Not a DAW. A process. You play pads, stack layers, and capture output. No piano roll, no playlist, no clicking in notes. You play the beat.

## Hardware
- **Arturia MiniLab 3** — primary input, pads trigger samples
- Samples sourced from **Splice**

## Core Workflow
1. Load samples onto pads
2. Set tempo (whole numbers only) and bar length (1, 2, or 4 bars)
3. Hit play — loop starts, metronome guides you
4. Play pads — what you play gets captured as a pattern layer
5. Loop comes back around — play more, stack another layer on top
6. Keep stacking until the beat is done
7. Press GOD — on the next pass, output is recorded to disk

## Transport
- **Play** — start the loop
- **Stop** — stop current playback
- **Stop All** — kill everything
- **Tempo** — whole numbers only, no decimals
- **Tap tempo** — tap a pad to set BPM naturally
- **Bar length** — 1, 2, or 4 bars

## Metronome
- Always available — this is your timeline since there's no visual grid
- Multiple sound options, all pleasant/soft (subtle clicks, woodblock, soft ticks)
- User-selectable sound
- Can be turned on/off

## Pattern System
- Each layer you record is a pattern
- Patterns stack — they all loop together
- Per-pattern controls:
  - On/off (mute/unmute)
  - Volume
  - Color/symbol-coded status
- Pattern states communicated through visual indicators:
  - Playing
  - Muted
  - Armed / recording
  - Current pattern being edited

## GOD Button — Genesis On Disk
- One button
- Press it — armed for next pass
- When the loop comes back around, starts capturing all audio output to disk
- Press again to stop capture
- Output saved as audio file

## Undo System
- **Undo last pass** — strips the last recorded layer instantly, no confirmation
- Redo available if you change your mind

## Visual System
- **No piano roll, no note grid, no waveform display, no playlist**
- All information communicated through colors, symbols, and indicators
- At a glance you know:
  - What patterns are playing
  - What's muted
  - What's armed
  - Where you are in the loop
  - What bar you're on
  - Pass counter (visual indicator, not just a number)
- Clean, modern terminal aesthetic — Claude-inspired theme (dark, muted purples/blues, premium feel)

## Master Output
- Master volume control

## Save System
- Manual save — you decide when
- Auto-save — periodic + on key actions
- Both coexist
- Full state restore on reopen

## Future Considerations (not v1)
- Pattern groups (mute/unmute groups at once)
- Sample manipulation (chop, pitch shift, time stretch, effects)
- Sample browser/preview
- Export/bounce options

## Tech Stack
- Python
- `textual` — TUI framework
- `mido` + `python-rtmidi` — MIDI input from MiniLab 3
- `sounddevice` — audio playback and capture
- Keep it light, fast startup, minimal dependencies

## Principles
- Performance-first — you play, it loops, you stack
- Information through aesthetics — colors and symbols, not grids
- Iterate constantly — ship, use, feel what's missing, add it
- No bloat

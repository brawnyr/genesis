# GOD UI Redesign

## Summary

Strip the current button-based SwiftUI layout and replace with a bold, keyboard-only interface. Claude-inspired aesthetic — bright whites, blues, oranges on dark background. Everything pops, nothing dim. The UI breathes and pulses with the music.

## Design Principles

- Keyboard only — no click interactions
- Bold and clear — white text that pops, no dim/muted elements
- Alive — breathing title, pulsing indicators, trigger flashes, bouncing signal meters
- Grows with the beat — empty channels are clean, active channels come alive
- Not a drum machine — a live loop instrument for iterating on beats

## Color Palette

- **Background**: deep dark (#1a1917)
- **Text**: bright white — always readable, always crisp
- **Blue**: active state — playing, active channels, beat indicators (Claude blue)
- **Orange**: hot state — recording, armed, capture, trigger moments
- **White flash**: pad trigger feedback (flash white, settle to blue)

## Layout (top to bottom)

### Title
`G   O   D` — breathing opacity animation, white

### Transport Strip
```
▶  120 bpm   4 bars   beat 3
```
- `▶` blue when playing, white `■` when stopped
- Beat number pulses blue on each beat
- All text bright white

### Loop Position Bar
Thin horizontal bar fills left to right in blue. Snaps back at loop boundary. Smooth animation.

### Channels (8 rows)
Three states per channel:

**Empty:**
```
3  —
```
White number, white dash.

**Loaded & active:**
```
1  kick      ●  ▊▊▊▊░░░
```
White name, blue filled dot, live signal meter in blue.

**Loaded & muted:**
```
2  snare     ○
```
White name, white hollow dot, no meter.

**Queued to record:**
```
4  perc      ○          REC
```
Orange pulsing `REC`. On next loop pass, starts capturing, then REC disappears and channel comes alive.

**Trigger flash:** entire channel row flashes white when pad fires, then settles back.

### GOD Capture
- Idle: white `○ GOD`
- Armed: orange `◉ GOD — armed` (pulsing)
- Recording: orange `◉ GOD — recording` (fast pulse)

### Tips
```
— the best code is the code you never write — claude
```
Typewriter effect, cycles through tips.

### Key Strip (always visible)
```
SPC play · G god · M metro · ↑↓ bpm · / cmd · ? keys
```
White text, always present.

### Command Input (hidden by default)
Press `/` to show:
```
> _
```
- Enter executes command and hides input
- ESC hides input without executing
- While focused, keyboard shortcuts disabled so you can type
- Supports: play, stop, god, bpm, mute, unmute, clear

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| SPC | Toggle play/stop |
| G | Toggle GOD capture (idle→armed→recording→idle) |
| M | Toggle metronome |
| ↑ | BPM +1 |
| ↓ | BPM -1 |
| ESC | Stop / dismiss command input |
| / | Focus command input |
| ? | Show full key reference overlay |
| 1-8 | Mute/unmute channel (new) |

## What Changes

### Views to rewrite
- **Theme.swift** — new color palette (add Claude blue, brighten everything)
- **ContentView.swift** — new layout, `/` focus logic, `?` overlay, 1-8 mute keys
- **TransportView.swift** — bold white text, blue play indicator, beat counter
- **LoopBarView.swift** — smooth blue fill bar, no beat markers text
- **PadGridView.swift** → **ChannelListView.swift** — replace pad grid with channel rows (signal meter, mute dot, REC indicator, trigger flash)
- **LayerListView.swift** — remove (merged into channel rows)
- **CaptureIndicatorView.swift** — simplify to single line, white/orange states
- **TipView.swift** — keep as-is
- **CommandInputView.swift** — hidden by default, `/` to show, ESC to hide
- **SetupView.swift** — keep (accessed via command `setup`)

### Views to remove
- **PadGridView.swift** — replaced by channel list
- **LayerListView.swift** — merged into channel list

### Engine changes
- Add per-channel signal level tracking (RMS or peak) to GodEngine
- Add per-channel "queued to record" state
- No other engine changes needed

### New components
- **ChannelRowView.swift** — single channel row with all states
- **SignalMeterView.swift** — horizontal bouncing level meter
- **KeyReferenceOverlay.swift** — full shortcut list shown on `?`

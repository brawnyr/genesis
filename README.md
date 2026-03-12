# GOD — Genesis On Disk

A playground for making music. Not a DAW — a personal instrument. Play pads, stack layers, shape the beat, capture the output.

Built with Swift, SwiftUI, CoreAudio, and CoreMIDI. Designed for the [Arturia MiniLab 3](https://www.arturia.com/products/hybrid-synths/minilab-3/overview), but works with any MIDI controller or just the keyboard.

## Requirements

- macOS 14+
- Xcode Command Line Tools (`xcode-select --install`)

## Quick Start

```bash
git clone https://github.com/brawnyr/god.git
cd god/GOD
swift build && .build/arm64-apple-macosx/debug/GOD
```

## Other Commands

```bash
swift build          # build only
swift test           # run tests
```

## How It Works

1. Set tempo and bar length (1, 2, or 4 bars)
2. Play pads via MIDI controller or keyboard — each pad triggers a sample and records into its own layer
3. Stack layers on top of each other to build a beat
4. Mute, unmute, and clear layers to shape the arrangement
5. Arm **GOD capture** to bounce the master output on the next loop boundary

### Keyboard Controls

| Key | Action |
|-----|--------|
| `SPC` | Play / pause |
| `A` / `D` | Cycle active pad left / right |
| `Shift+1-8` | Jump to pad |
| `Q` / `E` | Mute (cool) / unmute (hot) active pad |
| `G` | Arm GOD capture |
| `T` | Browse samples |
| `B` | BPM mode (W/S to scroll presets, type digits for custom) |
| `[ ]` | Cycle bar count (1, 2, 4) |
| `V` | Toggle master volume mode |
| `0-9` | Set volume (pad or master) |
| `M` | Metronome |
| `C` | Clear active pad layer |
| `X` | Toggle note-cut mode |
| `Z` | Undo last clear |
| `ESC` | Stop |
| `?` | Show key reference |

## Splice Integration (Optional)

If you use [Splice](https://splice.com), GOD can auto-sort your downloads into category folders that map directly to pads:

| Pad | Folder |
|-----|--------|
| 1 | kicks |
| 2 | snares |
| 3 | hats |
| 4 | perc |
| 5 | bass |
| 6 | keys |
| 7 | vox |
| 8 | fx |

To set up the background watcher:

```bash
python3 tools/splice_sorter.py --install
```

Use `--uninstall` to remove it, or `--dry-run` to preview what it would do.

## Project Structure

```
GOD/
  GOD/
    Models/    — Transport, Sample, Voice, Layer, Pad, Metronome, GodCapture
    Engine/    — GodEngine, AudioManager, MIDIManager
    Views/     — SwiftUI views
  Tests/       — Swift Testing unit tests
tools/
  splice_sorter.py — Splice download auto-sorter
```

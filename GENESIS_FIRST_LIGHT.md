# Genesis Design Vision — Codename: First Light

> Midnight canvas. Bright whites. Vivid blues. Full-spectrum pads.
> Every piece of text big enough to read without squinting.

---

## The Shift

**Forest Chrome** had problems: dark green on dark green means no contrast, earth tones sit in the same muddy range, tiny text everywhere, no zone labels, and all warm-toned pad colors that blur together.

**First Light** keeps the terminal energy and scoreboard numbers, but fixes everything else: midnight blue backgrounds, true bright white numbers, electric blue accents, a hard 17pt type floor, zone titles on everything, and pads that span the full color spectrum.

---

## Design Pillars

### 1. Midnight Canvas
Deep navy-black backgrounds (`#0B1120`). No green tint, no warm browns. Clean, neutral darkness that lets every color breathe.

### 2. White Heat
Hero numbers and active elements burn true white (`#F8FAFC`). Not silver, not cream — actual bright white that reads from across the room.

### 3. Electric Accent
Blue (`#3B82F6`) is the signature color. Section labels, dividers, oracle messages, and system identity all run through electric blue.

### 4. 17pt Floor
Nothing in the entire application renders below 17pt. Effect labels, file browser items, volume percentages, hit counts, pad data rows, timestamps, nav hints — all 17pt or larger. Big text stays big. Small text comes UP to 17. If text doesn't fit, make the container bigger — never the font smaller.

### 5. Every Zone Has a Title
MASTER, TERMINAL, HOTKEYS, PAD_SELECT, INSPECT, BROWSER — every section gets a labeled title in `sectionLabel` (20pt semibold, electric blue, tracking 3).

### 6. Full Spectrum Pads
Each of the 8 pads gets a truly distinct color spanning warm AND cool: orange, gold, sky blue, green, electric blue, violet, rose, mint.

---

## Core Palette

### Backgrounds
| Token      | Hex       | Usage                          |
|------------|-----------|--------------------------------|
| `midnight` | `#0B1120` | Base background                |
| `surface`  | `#111827` | Canvas, panels, bottom bar     |
| `elevated` | `#1A2332` | Hover states, raised surfaces  |
| `slate`    | `#1E293B` | Disabled elements, empty slots |

### Text
| Token    | Hex       | Usage                              |
|----------|-----------|-------------------------------------|
| `white`  | `#F8FAFC` | Hero numbers, active channel names  |
| `silver` | `#CBD5E1` | Standard body text, terminal lines  |
| `muted`  | `#64748B` | Labels, secondary info, timestamps  |

### Signature Blues
| Token      | Hex       | Usage                                    |
|------------|-----------|-------------------------------------------|
| `electric` | `#3B82F6` | Primary — section titles, dividers, oracle |
| `sky`      | `#7DD3FC` | Secondary — terminal highlights, links    |
| `ice`      | `#BAE6FD` | Rare emphasis, special states             |

### Semantic Colors
| Token       | Hex       | Usage                              |
|-------------|-----------|-------------------------------------|
| `sage`      | `#4ADE80` | Active/playing, success, toggles ON |
| `mint`      | `#34D399` | System messages, muted/frozen state |
| `ember`     | `#F97316` | Hot state, recording, triggers      |
| `terracotta`| `#EA580C` | Intense hot (dB clipping)           |
| `gold`      | `#FBBF24` | Edit mode, secondary warnings       |
| `clay`      | `#EF4444` | Stop, danger, recording indicator   |
| `rose`      | `#FB7185` | Vox accent, soft warnings           |

### Pad Colors — Full Spectrum
| Index | Pad    | Hex       | Description    |
|-------|--------|-----------|----------------|
| 0     | KICKS  | `#F97316` | Bright orange  |
| 1     | SNARES | `#FBBF24` | Electric gold  |
| 2     | HATS   | `#7DD3FC` | Sky blue       |
| 3     | PERC   | `#4ADE80` | Vivid green    |
| 4     | BASS   | `#3B82F6` | Electric blue  |
| 5     | KEYS   | `#A78BFA` | Soft violet    |
| 6     | VOX    | `#FB7185` | Warm rose      |
| 7     | FX     | `#34D399` | Mint           |

### Separator
```
electric.opacity(0.12)  →  rgba(59, 130, 246, 0.12)
```

---

## Typography

### HARD RULE: 17pt Minimum

Nothing renders below 17pt. `monoTiny` (11pt) and `monoSmall` (14pt) are eliminated — they alias to `mono` (17pt).

| Token          | Size       | Weight   | Usage                          |
|----------------|------------|----------|--------------------------------|
| `hero`         | 52pt       | Bold     | BPM, volume, dB (scoreboard)  |
| `title`        | 36pt       | Bold     | Channel name in inspector      |
| `monoLarge`    | 22pt       | Bold     | Hotkey keys, big labels        |
| `sectionLabel` | 20pt       | Semibold | Zone titles (MASTER, TERMINAL, etc.) |
| `mono`         | **17pt**   | Regular  | **THE FLOOR — everything else** |

### What gets bumped up
| Was                    | Used for                         | Now                    |
|------------------------|----------------------------------|------------------------|
| `monoTiny` (11pt)      | Effect dots, hit counts, hints  | `mono` (17pt)          |
| `monoSmall` (14pt)     | Labels, status, BPM/VOL/BAR    | `mono` (17pt)          |
| `sectionLabel` (15pt)  | MASTER, INSPECT, PAD_SELECT     | `sectionLabel` (20pt)  |
| File browser items     | 10-14pt                         | `mono` (17pt)          |
| PadDataRow values      | 12pt                            | `mono` (17pt)          |
| Nav hints              | 8-9pt                           | `mono` (17pt)          |

### Type color rules
- **Hero numbers:** `chrome` (#F8FAFC) with `shadow: electric.opacity(0.25), radius: 8`
- **Section labels:** `electric` (#3B82F6) with `tracking: 3`
- **Terminal body:** `silver` (#CBD5E1) base, colored per message type
- **Status labels:** `muted` (#64748B) when inactive, `white` when active

---

## Zone Titles

Every section has a title. Non-negotiable.

| Zone           | Title text     |
|----------------|---------------|
| Master HUD     | `MASTER`       |
| Terminal        | `TERMINAL`     |
| Hotkey bar      | `HOTKEYS`      |
| Pad selector    | `PAD_SELECT`   |
| Inspector       | `INSPECT`      |
| Sample browser  | `BROWSER`      |

All: `sectionLabel` · `electric` · tracking 3

---

## Glow System

| State             | Glow color            | Opacity | Radius |
|-------------------|-----------------------|---------|--------|
| Hero numbers      | `electric`            | 0.25    | 8      |
| Active pad        | `padColor`            | 0.20    | 8      |
| Section labels    | `electric`            | 0.30    | 6      |
| Active toggle     | `sage`                | 0.40    | 3      |
| Recording         | `clay`                | 0.40    | 3      |
| Hotkey key text   | group color           | 0.30    | 4      |

---

## Terminal Color Mapping

| Message type | Color       | Hex       |
|-------------|-------------|-----------|
| system      | `mint`      | `#34D399` |
| transport   | `mint`      | `#34D399` |
| hit         | `padColor`  | (varies)  |
| state       | `silver`    | `#CBD5E1` |
| capture     | `ember`     | `#F97316` |
| browse      | `sky`       | `#7DD3FC` |
| oracle      | `electric`  | `#3B82F6` |

Cursor: `electric` (#3B82F6), blinking.

---

## Do / Don't

### Do
- Set 17pt as the minimum — every label, every value, everywhere
- Give every zone a titled header in electric blue (20pt semibold)
- Use bright white for any number that matters
- Use electric blue for all section labels and dividers
- Give active elements a glow shadow in their color
- Keep pads visually distinct — use the full spectrum
- Use midnight blue backgrounds (neutral, not tinted)
- If text doesn't fit, make the container bigger, not the font smaller

### Don't
- Use any font size below 17pt — not 14, not 11, not 9
- Create a section without a labeled title
- Use gray or silver where white should be
- Tint backgrounds green or brown
- Make all pad colors from the same warm range
- Use ember for non-recording states
- Add borders where a glow shadow would work
- Shrink text to fit a layout — resize the layout instead

---

## Migration Checklist

| File                     | Changes needed                                                          |
|--------------------------|-------------------------------------------------------------------------|
| `Theme.swift`            | Replace entirely — midnight palette, 17pt floor, monoSmall/monoTiny aliased to mono |
| `GHUD.swift`             | Add MASTER sectionLabel. All labels → mono (17pt). Heroes → chrome. Shadows → electric |
| `BeatTrackerHUD.swift`   | Labels (BPM, BEAT, BAR) → mono (17pt). Numbers → chrome. Border → separator |
| `ContentView.swift`      | Add HOTKEYS and TERMINAL sectionLabel titles                            |
| `PadInspectPanel.swift`  | INSPECT → electric. All rows → mono (17pt). Channel name → chrome      |
| `PadSelect.swift`        | PAD_SELECT → electric. ALL data rows → mono (17pt)                     |
| `SampleBrowserView.swift`| BROWSER → electric. File items → mono (17pt). Nav hints → 17pt        |
| `TerminalTextLayer.swift`| Add TERMINAL title. All lines 17pt. oracle→electric, browse→sky        |

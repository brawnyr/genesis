# Genesis UI Redesign Spec

## Design Direction

**Codename: Forest Chrome**

The current UI is too monochrome, low-contrast, and small. Everything blends together. This redesign transforms Genesis into a luxury terminal built in a dark forest — deep green backgrounds, bright chrome/silver highlights, bold earthy pad colors, and scoreboard-sized numbers you can read from across the room.

### Design Pillars

1. **Deep forest background** — not black, not brown. Dark green like looking into a forest at night.
2. **Chrome/silver accents** — bright white-silver for active states, key numbers, and highlights. Clean and modern.
3. **Bold earth-tone pad colors** — each of the 8 pads gets a unique, saturated color from the earth spectrum. Way bolder than current.
4. **Scoreboard typography** — BPM, volume, dB should be HUGE (52pt+). Everything else bumps up significantly too.
5. **Retro-digital font energy** — monospaced throughout, techy feel. Optionally bundle a pixel font later.
6. **Subtle zone separation** — thin lines or 1px gaps between zones, not bold borders.

---

## File: `Views/Theme.swift`

**Replace the entire file** with this new theme:

```swift
import SwiftUI

enum Theme {
    // ═══════════════════════════════════════════════════════════════
    //  GENESIS — Deep Forest / Chrome design system
    // ═══════════════════════════════════════════════════════════════

    // Background — deep forest at night
    static let bg = Color(red: 0.051, green: 0.102, blue: 0.071)            // #0d1a12

    // Canvas — the darkest layer, near-black green
    static let canvasBg = Color(red: 0.035, green: 0.071, blue: 0.047)      // #091208

    // Text — bright silver, clean and readable
    static let text = Color(red: 0.847, green: 0.878, blue: 0.855)          // #d8e0da

    // Chrome — pure highlight, white-silver flash for active states
    static let chrome = Color(red: 0.941, green: 0.957, blue: 0.945)        // #f0f4f1

    // Sage — active state, playing, channels
    static let sage = Color(red: 0.400, green: 0.690, blue: 0.420)          // #66b06b

    // Moss — system messages, muted/frozen state
    static let moss = Color(red: 0.500, green: 0.680, blue: 0.530)          // #80ad87

    // Terracotta — hot state, recording, triggers, alive
    static let terracotta = Color(red: 0.878, green: 0.400, blue: 0.220)    // #e06638

    // Forest — oracle, success, positive feedback
    static let forest = Color(red: 0.310, green: 0.620, blue: 0.340)        // #4f9e57

    // Clay — warnings, pad labels, stop
    static let clay = Color(red: 0.820, green: 0.310, blue: 0.250)          // #d14f40

    // Wheat — edit mode, secondary warnings
    static let wheat = Color(red: 0.878, green: 0.690, blue: 0.290)         // #e0b04a

    // Subtle — muted forest for empty slots, hints, disabled
    static let subtle = Color(red: 0.145, green: 0.200, blue: 0.165)        // #25332a

    // Zone separator — subtle thin lines between UI zones
    static let separator = Color(red: 0.200, green: 0.310, blue: 0.230).opacity(0.4)

    // Pad channel colors — bold earth spectrum (MUCH more saturated than before)
    static let padColors: [Color] = [
        Color(red: 0.831, green: 0.345, blue: 0.188),  // kicks — bold rust       #d4582f
        Color(red: 0.831, green: 0.541, blue: 0.188),  // snares — rich amber      #d48a30
        Color(red: 0.831, green: 0.659, blue: 0.157),  // hats — bright gold       #d4a828
        Color(red: 0.435, green: 0.627, blue: 0.188),  // perc — vivid olive       #6fa030
        Color(red: 0.220, green: 0.565, blue: 0.227),  // bass — deep emerald      #38903a
        Color(red: 0.722, green: 0.439, blue: 0.251),  // keys — warm sienna       #b87040
        Color(red: 0.753, green: 0.376, blue: 0.439),  // vox — dusty mauve        #c06070
        Color(red: 0.784, green: 0.659, blue: 0.314),  // fx — sandy gold          #c8a850
    ]

    static func padColor(_ index: Int) -> Color {
        padColors[index % padColors.count]
    }

    // ═══════════════════════════════════════════════════════════════
    //  TYPOGRAPHY — big, bold, retro-digital
    // ═══════════════════════════════════════════════════════════════
    //
    //  OPTIONAL: For true pixel/bitmap feel, bundle one of these OFL fonts:
    //    • "Silkscreen" by Jason Kottke
    //    • "Press Start 2P" from Google Fonts
    //    • "Cozette" by slavfox (MIT)
    //  Add the .ttf to Xcode target + Info.plist "Fonts provided by application"
    //  Then swap .monospaced → .custom("FontName", size: N)

    // Hero numbers — BPM, master volume, dB (SCOREBOARD SIZE)
    static let hero = Font.system(size: 52, design: .monospaced).weight(.bold)

    // Channel name in inspect panel
    static let title = Font.system(size: 36, design: .monospaced).weight(.bold)

    // Standard mono text — terminal lines, inspector rows
    static let mono = Font.system(size: 17, design: .monospaced)

    // Small mono — labels, status indicators
    static let monoSmall = Font.system(size: 14, design: .monospaced)

    // Large mono — hotkey keys, section headers
    static let monoLarge = Font.system(size: 20, design: .monospaced).weight(.bold)

    // Tiny — effect dots, hit counts
    static let monoTiny = Font.system(size: 11, design: .monospaced)

    // Section header label
    static let sectionLabel = Font.system(size: 15, design: .monospaced).weight(.semibold)

    // Legacy aliases — use new names in new code
    static let blue = sage
    static let ice = moss
    static let orange = terracotta
    static let green = forest
    static let red = clay
    static let amber = wheat
}
```

---

## File: `Views/GHUD.swift`

The master volume/dB area. Key changes:

- **"MASTER" title**: use `Theme.sectionLabel`, color `Theme.chrome`, tracking 3, with chrome glow
- **VOL label**: `Theme.monoSmall.bold()`, color `Theme.sage` (green label, not terracotta)
- **Volume number**: `Theme.hero` (52pt), color `Theme.chrome` with chrome glow shadow
- **dB number**: `Theme.hero` (52pt), color logic stays (clay > 0, terracotta > -6, else `Theme.chrome`)
- **dB label**: `Theme.monoSmall.bold()`, color `Theme.sage`
- **Divider line**: use `Theme.separator` instead of `Theme.terracotta.opacity(0.15)`
- **Status indicators** (VEL, METRO, REC):
  - Dot size: 9pt (was 7pt)
  - Active color: `Theme.sage` (was terracotta) for VEL and METRO
  - Text: `Theme.monoSmall.bold()`, active = `Theme.chrome`, inactive = `Theme.subtle`
  - REC stays `Theme.clay`
- **Spacing**: bump `.padding(.horizontal, 20)`, `.padding(.vertical, 14)`, `.frame(width: 360)` in parent

---

## File: `Views/BeatTrackerHUD.swift`

The floating bottom-center HUD. Key changes:

- **All numbers** (BPM value, beat position, bar count): `Theme.hero` (52pt), color `Theme.chrome`, shadow `Theme.chrome.opacity(0.3), radius: 8`
- **All labels** (BPM, BEAT, BAR): `Theme.monoSmall.bold()`, color `Theme.sage`
- **Loop seconds text**: `Theme.monoTiny`, `Theme.text.opacity(0.3)`
- **Inactive beat dash**: `Theme.hero`, `Theme.text.opacity(0.15)`
- **Dividers**: `Theme.separator`, height 36 (was 28)
- **HStack spacing**: 28 (was 20)
- **Status dots**: 10pt (was 8pt), with stronger shadow radius 5
- **Background**: `Theme.canvasBg.opacity(0.95)` stays, but border becomes `Theme.separator` instead of terracotta
- **Padding**: `.horizontal 24`, `.vertical 12`

---

## File: `ContentView.swift`

Layout container. Key changes:

- **HStack spacing**: change from `spacing: 0` to `spacing: 1` (the 1px gap IS the zone separator)
- **Add `Rectangle().fill(Theme.separator).frame(height: 1)`** between the HotkeyHUD and terminal area
- **Add `Rectangle().fill(Theme.separator).frame(height: 1)`** between the terminal area and the bottom bar
- **Add `Rectangle().fill(Theme.separator).frame(width: 1)`** between GHUD and PadSelect in the bottom HStack
- **Bottom bar height**: 240 (was 220) to give pads more room
- **GHUD width**: 360 (was 320) to accommodate bigger numbers
- **Min window size**: `minWidth: 960, minHeight: 640` (was 900x600)

### HotkeyHUD changes:

- **VStack spacing**: 8 (was 6)
- **HStack spacing**: 24 (was 20)
- **Key text**: `Theme.monoLarge` (20pt bold, was 16pt bold)
- **Action text**: `Theme.monoSmall` (14pt, was 15pt), `Theme.text.opacity(0.5)` (was 0.6)
- **HStack inner spacing**: 12 (was 10)
- **Padding**: `.horizontal 24` (was 20), `.vertical 10` (was 8)
- **Pad nav group color**: `Theme.chrome` instead of `Theme.terracotta` — makes the pad navigation keys pop white

---

## File: `Views/TerminalTextLayer.swift`

The scrolling log. Key changes:

### TerminalTextLayer:
- **Cursor**: font size 17 (was 14), still `Theme.terracotta`
- **VStack spacing**: 2 (was 1) for slightly more breathing room
- **Padding**: 20 (was 16)

### TerminalLineView:
- **All text**: `Theme.mono` (17pt, was 14pt)
- **Timestamp color**: `Theme.subtle.opacity(0.6)` (was 0.8) — dimmer so it recedes more
- **Chevron** `" > "`: color stays `color.opacity(0.4)`
- **Line text shadow**: `color.opacity(0.35), radius: 4` (was 0.3, radius 3) — slightly stronger glow

Color mapping stays the same (system→moss, transport→moss, hit→padColor or terracotta, state→text, capture→terracotta, browse→moss, oracle→forest).

---

## File: `Views/PadInspectPanel.swift`

The right sidebar. Key changes:

### PadInspectPanel:
- **"INSPECT" title**: `Theme.sectionLabel` (15pt semibold, was 11pt bold), color `Theme.chrome`, tracking 3, chrome glow
- **Panel width**: 280 (was 260)
- **Padding**: 20 (was 18)

### Channel name (hero text):
- **Font**: `Theme.title` (36pt bold, was 28pt)
- **Tracking**: 3 (was 2)
- **Unmuted color**: `Theme.chrome` (was `Theme.clay`) — the channel name should POP in silver
- **Muted color**: `Theme.moss` (stays same)

### InspectorSectionHeader:
- **Arrow + title font**: `Theme.sectionLabel` (15pt, was 14pt)
- **Arrow color**: keep as passed `color` param
- **Title color**: `Theme.chrome` (was `Theme.text`), tracking 2 (was 1.5)

### InspectorRow:
- **Font**: `Theme.mono` (17pt, was 16pt)
- **Label color**: `Theme.text.opacity(0.5)` (was 0.7) — dimmer labels, brighter values
- **Value color**: non-highlight = `Theme.chrome` (was `Theme.text`), highlight = `Theme.terracotta` (stays)
- **Vertical padding**: 4 (was 3)

### ChokeBadge:
- **"CHOKE" label**: `Theme.text.opacity(0.5)` (was 0.7)
- **ON/OFF text**: 16pt (was 15pt)
- **ON color**: `Theme.sage` (was terracotta) — green for active toggle
- **ON background**: `Theme.sage.opacity(0.12)`, border `Theme.sage.opacity(0.25)`
- **Description text**: 12pt (was 11pt)

### Dividers throughout:
- Replace `Theme.text.opacity(0.06)` with `Theme.separator` for all `Rectangle()` dividers

---

## File: `Views/PadSelect.swift`

The 8-pad strip at the bottom. Key changes:

### PadSelect:
- **"PAD_SELECT" title**: `Theme.sectionLabel` (15pt, was 11pt), color `Theme.chrome`, tracking 3
- **HStack spacing**: 3 (was 2)
- **Title padding**: `.horizontal 12`, `.top 8`, `.bottom 6`

### PadCell:
- **Pad name font**: active = 20pt bold (was 16pt), inactive = 13pt bold (was 11pt)
- **Volume bar width**: active = 18 (was 14), inactive = 10 (was 8)
- **Volume bar height**: 50 (was 40)
- **Volume bar fill opacity**: 0.75 (was 0.6) — bolder color in the bar
- **Volume % text**: `Theme.monoTiny` (11pt, was 10pt), `Theme.text.opacity(0.4)` (was 0.5)
- **Active background**: `padColor.opacity(0.12)` (was 0.08)
- **Active shadow**: `padColor.opacity(0.2), radius: 8` (was 0.15, radius 6)
- **Active border**: `padColor.opacity(0.4)` (was 0.3)
- **Cell padding**: `.vertical 8` (was 6)

### EffectDot:
- **Font**: `Theme.monoTiny` (11pt bold, was 8pt bold)
- **Frame**: 16x16 (was 12x12)
- **Background circle opacity**: 0.2 (was 0.15)

### Hit count:
- **Font**: `Theme.monoTiny` (11pt, was 9pt)
- **Color opacity**: 0.5 (was 0.4)

---

## File: `Views/SampleBrowserView.swift`

The file browser in the inspect panel. Key changes:

- **"BROWSER" title**: `Theme.sectionLabel` (was 12pt), color `Theme.chrome` (was terracotta)
- **"[T] close" text**: `Theme.monoTiny` (was 9pt), `Theme.text.opacity(0.3)` (was `Theme.subtle`)
- **"empty folder" text**: `Theme.monoSmall` (was 10pt)
- **"OPEN FILE..." button**: `Theme.monoSmall.bold()` (was 11pt), color `Theme.sage`
- **File list items**: `Theme.monoSmall` (14pt, was 10pt)
- **Selected file color**: `Theme.chrome` (was terracotta)
- **Selected file background**: `Theme.sage.opacity(0.1)` (was terracotta)
- **Selected file shadow**: `Theme.sage.opacity(0.3)` (was terracotta)
- **Unselected file color**: `Theme.text.opacity(0.35)`
- **Max name length**: 22 chars (was 18) since panel is wider now
- **Nav hints**: `Theme.monoTiny` (was 8pt)
- **Dividers**: use `Theme.separator`

---

## Summary of the new color language

| Role | Old | New |
|------|-----|-----|
| Background | Warm brown `#2a2520` | Deep forest `#0d1a12` |
| Canvas | Dark brown `#221e1a` | Near-black green `#091208` |
| Primary text | Cream `#f0ebe3` | Silver `#d8e0da` |
| **Hero/highlight** | *(didn't exist)* | **Chrome `#f0f4f1`** |
| Active/playing | Sage `#7a8c50` | Brighter sage `#66b06b` |
| System msgs | Moss `#9aaa78` | Brighter moss `#80ad87` |
| Recording/hot | Terracotta `#c4734a` | Bolder terracotta `#e06638` |
| Success/oracle | Forest `#6b8040` | Vivid forest `#4f9e57` |
| Warning/stop | Clay `#b5614e` | Bold clay `#d14f40` |
| Edit/secondary | Wheat `#c49a52` | Rich wheat `#e0b04a` |
| Disabled/empty | Warm gray `#3a3530` | Muted forest `#25332a` |

## Summary of the new type scale

| Token | Old size | New size | Usage |
|-------|----------|----------|-------|
| `hero` | *(didn't exist)* | **52pt bold** | BPM, volume, dB — scoreboard |
| `title` | *(didn't exist)* | **36pt bold** | Channel name in inspector |
| `monoLarge` | 22pt | **20pt bold** | Hotkey keys, section headers |
| `mono` | 16pt | **17pt** | Terminal lines, inspector rows |
| `sectionLabel` | *(didn't exist)* | **15pt semibold** | MASTER, INSPECT, PAD_SELECT headers |
| `monoSmall` | 14pt | **14pt** | Labels, status text |
| `monoTiny` | *(didn't exist)* | **11pt** | Effect dots, hit counts, hints |

---

## Key principles for implementation

1. **Theme.chrome is the new star** — use it for any number or label that should grab attention. It replaces `Theme.text` in most prominent positions and replaces `Theme.terracotta` for section titles.
2. **Theme.sage replaces terracotta for "on" indicators** — active toggles (VEL, METRO, CHOKE ON) glow green, not orange. Reserve terracotta for recording and hot/destructive states.
3. **Theme.separator for all dividers** — every `Rectangle()` that was using `Theme.text.opacity(0.06)` or `Theme.terracotta.opacity(0.15)` should now use `Theme.separator`.
4. **Shadows are intentional** — chrome elements get `chrome.opacity(0.25-0.3), radius: 6-8`. Pad colors get `padColor.opacity(0.2), radius: 8` when active. This creates the "glow" effect on the dark forest background.
5. **No cold black anywhere** — both `bg` and `canvasBg` have green in them. The subtle color also has green. The whole app should feel like it lives in a forest, not a void.

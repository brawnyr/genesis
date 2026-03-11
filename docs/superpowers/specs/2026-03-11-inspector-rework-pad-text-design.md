# Inspector Rework, Pad Text & Cut Mode

**Date:** 2026-03-11
**Status:** Approved

## Summary

Two UI improvements and two new engine features for GOD:

1. **Pad sample name text** — bigger font, marquee scroll for long names instead of squeezing
2. **Inspector panel rework** — log-style terminal aesthetic with sectioned output, remove pad number, channel name as hero
3. **Cut mode** — per-pad monophonic/polyphonic toggle for loop-chopping behavior
4. **BPM detection** — auto-detect sample BPM and display in inspector

## 1. Pad Strip Text Changes

**File:** `GOD/GOD/Views/PadStripView.swift` — `PadCell`

### Current behavior
- Font: 12pt bold monospaced
- `minimumScaleFactor(0.5)` — long names shrink down to ~6-7pt, unreadable
- Single line, no overflow handling

### New behavior
- Font: **14pt bold monospaced** (locked size, no scaling)
- Remove `minimumScaleFactor(0.5)` entirely
- **Marquee scroll**: when the rendered text width exceeds the available pad width, animate a smooth horizontal scroll loop. Short names that fit remain static.
- Implementation: use a `GeometryReader` to measure available width, compare against text width. If overflow detected, use a `TimelineView` or repeating animation to translate the text left, with a seamless loop (duplicate the text with a spacer gap between copies).
- All other pad styling unchanged (colors, glow, signal meter, folder label, top border)

## 2. Inspector Panel Rework

**File:** `GOD/GOD/Views/PadStripView.swift` — `CCPanelView` + `padReadoutView`

### Design direction
Log-style terminal output. Information presented as if streaming from a live process. Sectioned with dim headers, indented values, subtle dividers. Matches the Claude Code / terminal aesthetic established in the project's design principles.

### Layout structure

```
~ MASTER
  82%

─────────────────────

KICKS                     ← folderName (PadBank.spliceFolderNames[activeIndex])

─────────────────────

▶ SAMPLE
    file  kick_808_deep.wav
    dur   0.82s
    bpm   140

─────────────────────

▶ PARAMS
    vol   82%
    pan   C
    HP    20Hz
    LP    20kHz

─────────────────────

▶ MODE
    cut   [ON]
```

### Changes from current

| Element | Before | After |
|---------|--------|-------|
| Pad number | 28pt bold, prominent | **Removed entirely** |
| Channel name | 16pt `folderName`, secondary to pad number | **22pt bold, hero element, letter-spacing 2pt, orange glow. Source: `PadBank.spliceFolderNames[activeIndex].uppercased()`** |
| Sample name | 13pt, single dim line as hero | **Moved into SAMPLE section as `file` row, 12pt, secondary info** |
| Background | `Color(red: 0.1, green: 0.095, blue: 0.088)` | **`Color(red: 0.071, green: 0.067, blue: 0.059)`** |
| Section headers | None | **`▶ SAMPLE`, `▶ PARAMS`, `▶ MODE`** — 10pt, dim, uppercase, letter-spaced |
| Dividers | Single `Divider()` | **1px dividers at `Color.white.opacity(0.04)` between sections** |
| CC params | Flat list, 14pt | **Indented under PARAMS header, 13pt** |
| Cut mode | Does not exist | **New MODE section with badge indicator** |
| Sample info | Does not exist | **New SAMPLE section with file, dur, bpm** |

### Styling details

- **Master section**: `~` prefix in `Theme.orange.opacity(0.4)`, "MASTER" label 11pt `Color.white.opacity(0.35)`, value 36pt bold with `.shadow(color: Theme.orange.opacity(0.15), radius: 20)`
- **Channel name**: 22pt bold monospaced, `Theme.orange`, letter-spacing 2pt, `.shadow(color: Theme.orange.opacity(0.4), radius: 25)`. For cold/muted channels use `Theme.ice` instead.
- **Section headers**: 10pt monospaced, `Color.white.opacity(0.3)`, letter-spacing 0.5pt, `▶` prefix in `Theme.blue.opacity(0.5)` for SAMPLE, `Theme.orange.opacity(0.5)` for PARAMS/MODE
- **Row labels**: 12-13pt monospaced, `Color.white.opacity(0.3)`, fixed width for alignment
- **Row values**: 12-13pt monospaced, `Color.white.opacity(0.6)` default, `Theme.orange` with `.shadow` glow when active/highlighted
- **Cut badge**: inline pill — `ON`: orange text, `Theme.orange.opacity(0.15)` background, `Theme.orange.opacity(0.3)` border, text shadow. `OFF`: `Color.white.opacity(0.3)` text, no glow.
- **Duration format**: guard `pad.sample` is non-nil, then `String(format: "%.2fs", sample.durationMs / 1000.0)` — e.g. `0.82s`. Source: `Sample.durationMs` (already exists on the model). Show `--` if no sample loaded.

### Panel width
Keep at **190pt**.

## 3. Cut Mode (Engine Feature)

### Concept
- **Cut OFF** (default) = polyphonic — multiple voices of the same pad ring out simultaneously. Current behavior.
- **Cut ON** = monophonic — triggering a new note on a pad stops all currently playing voices **for that same pad** before starting the new voice. Essential for 808-style playing and loop chopping.

**Note:** This is per-pad cut, not cross-pad choke groups. Pad 1 cutting does not affect Pad 2's voices. Each pad independently decides whether its own voices chop each other.

### Model changes

**`Layer` struct** (`GOD/GOD/Models/Layer.swift`) — add runtime property:
```swift
var cut: Bool = false
```

**`PadAssignment` struct** (`GOD/GOD/Models/Pad.swift`) — add persisted optional property:
```swift
struct PadAssignment: Codable {
    let path: String
    let name: String
    var cut: Bool?  // new — nil in existing pads.json, treated as false
}
```

Using `Bool?` ensures synthesized `Decodable` uses `decodeIfPresent`, so existing `pads.json` files without a `cut` key decode without error. Consumers read it as `assignment.cut ?? false`.

### Persistence

**Saving**: Add a `cut` property to `Pad` struct that `GodEngine` syncs from `Layer.cut` before saving:
```swift
// In Pad struct:
var cut: Bool = false

// In PadBank.config computed property, include cut:
cfg.assignments[String(pad.index)] = PadAssignment(path: path, name: pad.name, cut: pad.cut)

// In GodEngine, before padBank.save():
for i in 0..<8 {
    padBank.pads[i].cut = layers[i].cut
}
try? padBank.save()
```

**Loading**: `PadBank.loadConfig()` does not have access to `Layer` (layers live on `GodEngine`). Restore cut values in `GodEngine` after `padBank.loadConfig()` returns:
```swift
// In GodEngine, after padBank.loadConfig():
for i in 0..<8 {
    let cutValue = padBank.pads[i].cut  // populated from PadAssignment during loadConfig
    layers[i].cut = cutValue
    audioLayers[i].cut = cutValue
}
```

In `PadBank.loadConfig()`, when restoring from `PadAssignment`, also set `pads[index].cut = assignment.cut ?? false`.

### Engine changes

**Audio thread sync** — follow the same pattern as `toggleMute`. Add a `toggleCut` method on `GodEngine`:
```swift
func toggleCut(pad index: Int) {
    guard index >= 0, index < layers.count else { return }
    layers[index].cut.toggle()
    audioLayers[index].cut = layers[index].cut
}
```
This mirrors the `toggleMute` pattern (line 92-96 of GodEngine.swift) where both `layers` and `audioLayers` are updated together on the main thread. This is safe because `audioLayers` reads happen on the audio thread but writes from main thread are atomic for Bool.

**Voice chopping** — in `handlePadHit`, before appending the new voice:
```swift
if audioLayers[padIndex].cut {
    voices.removeAll { $0.padIndex == padIndex }
}
```

Also add the same cut check in `processBlock` where layer hits spawn voices (the loop-playback path, ~line 194-198):
```swift
for hit in hits {
    if let sample = padBank.pads[layer.index].sample {
        if layer.cut {
            voices.removeAll { $0.padIndex == layer.index }
        }
        let vel = Float(hit.velocity) / 127.0 * layer.volume
        voices.append(Voice(sample: sample, velocity: vel, padIndex: layer.index))
    }
}
```

**`AudioManager.swift` is NOT involved** — it's a thin `AVAudioEngine` wrapper with no voice logic.

### Keyboard control

**Key: `C`** — toggles cut for `activePadIndex`. Add to the keyboard handler (likely in the main `ContentView` or wherever `.onKeyPress` is handled):
```swift
case "c":
    engine.toggleCut(pad: engine.activePadIndex)
```

## 4. BPM Detection

### Concept
Auto-detect BPM from loaded audio samples using onset detection.

### Storage approach
Since `Sample` is a value-type struct that doesn't mutate after creation, store detected BPM **separately** as a `@Published` dictionary on `GodEngine`:

```swift
@Published var detectedBPMs: [Int: Double] = [:]  // keyed by pad index
```

This avoids needing to mutate the `Sample` struct after it's been assigned to a pad.

### Detection approach
- New file: `GOD/GOD/Engine/BPMDetector.swift`
- Takes a `Sample`'s `left` buffer and `sampleRate` (note: `sampleRate` is always `Transport.sampleRate` after resampling in `Sample.load`)
- Uses energy-based onset detection to find beat positions
- Calculates inter-onset intervals and derives BPM
- Returns `Double?` (nil if detection fails)
- Run detection on a background `Task` after sample load, update `detectedBPMs[padIndex]` on main thread on completion

### Display
- Show in inspector SAMPLE section as `bpm   140` (rounded to integer)
- Show `bpm   --` if detection fails, sample is too short (< 0.5s), or still detecting (`detectedBPMs[activeIndex] == nil`)

### Edge cases
- Very short samples (< 0.5s / fewer than ~22050 frames): skip detection, return nil
- Ambiguous BPM (could be half/double): prefer range 70-180 BPM
- Detection runs once on load, result cached in `detectedBPMs` dictionary
- When a pad's sample changes, clear `detectedBPMs[padIndex]` and re-run detection

## Files Affected

| File | Changes |
|------|---------|
| `GOD/GOD/Views/PadStripView.swift` | Pad text sizing + marquee, full inspector panel rework |
| `GOD/GOD/Views/Theme.swift` | Possibly new color constants for section headers |
| `GOD/GOD/Models/Layer.swift` | Add `cut: Bool` runtime property |
| `GOD/GOD/Models/Pad.swift` | Add `cut: Bool?` to `PadAssignment`, add `cut: Bool` to `Pad`, update `PadBank.config` and `loadConfig` |
| `GOD/GOD/Engine/GodEngine.swift` | `toggleCut()`, cut voice stopping in `handlePadHit` + `processBlock`, `detectedBPMs` dictionary, cut restore on config load |
| `GOD/GOD/Views/ContentView.swift` (or key handler) | `C` keyboard shortcut for cut toggle |
| New: `GOD/GOD/Engine/BPMDetector.swift` | BPM detection algorithm |

## Out of Scope

- MIDI control for cut toggle (keyboard only for now)
- Cross-pad choke groups (cut is per-pad only)
- BPM sync between samples and transport
- Inspector layout changes beyond what's described here

# Swing & Terminal Trigger View — Design Spec

## Overview

Two features for the GOD looper to bring it closer to MPC/FL Studio workflow:

1. **Per-pad swing** — live, non-destructive groove shift applied at playback time
2. **Terminal trigger view** — crystalline multi-track piano roll in the canvas showing all active pad hits

## Feature 1: Per-Pad Swing

### Data Model

Add `swing: Float` to `Layer`. Range 0.5–0.75, default 0.5 (straight). 0.5 = no swing, 0.75 = heavy MPC shuffle. Stored in the audio thread mirror as `audio.layers[i].swing`.

### Playback Behavior (ProcessBlock)

Swing operates on sixteenth-note pairs. The loop is divided into sixteenth notes:

```
sixteenthLengthFrames = loopLengthFrames / (beatsPerLoop * 4)
maxSwingOffset = (0.75 - 0.5) * sixteenthLengthFrames  // max possible shift
```

**Hit scan with swing — expanded range strategy:**

The existing binary-search range query (`layer.hits(inRange:)`) looks at stored positions. Since swing shifts hits forward, a hit stored before the current block could play during it. The scan range is expanded backward by `maxSwingOffset`:

```
scanStart = blockStart - maxSwingOffset   // look earlier to catch hits swung into this block
scanEnd = blockEnd                        // no expansion needed on the right
```

For each hit found in the expanded scan:
1. Classify which sixteenth-note slot it belongs to: `slotIndex = round(hit.frame / sixteenthLengthFrames)`
2. If `slotIndex` is odd (the "off" beat in each pair), compute the swung position:
   ```
   swungFrame = hit.frame + (layer.swing - 0.5) * sixteenthLengthFrames
   ```
3. If `slotIndex` is even, `swungFrame = hit.frame` (no shift)
4. Only trigger the hit if `swungFrame` falls within `blockStart..<blockEnd`

**Loop-wrap behavior:** If `swungFrame >= loopLengthFrames`, it wraps: `swungFrame % loopLengthFrames`. This means the last swung hit in a loop can wrap to the beginning. The wrap-aware scan logic in ProcessBlock already handles split ranges across the loop boundary — the same pattern applies to swung positions.

**Classification tolerance:** Hits are classified to the nearest sixteenth-note slot via rounding. This works naturally — a hit at any position gets assigned to its closest grid line, and the odd/even classification determines if swing applies. No explicit tolerance zone needed since `round()` provides a clean split.

Hits are never modified in memory — swing is pure playback math.

### Non-Destructive

- Stored hit positions unchanged
- Swing can be adjusted live mid-performance via CC knob
- Turning swing back to 0.5 returns to exact recorded timing

### Control

- **CC 18**: mapped to active pad's swing (0–127 → 0.5–0.75 range)
- **Keyboard**: `V` / `Shift+V` to nudge swing up/down by 0.01

### Audio Thread Sync

- `swing` value mirrored in `audio.layers[i].swing` like volume/pan/cutoff
- Updated from CC handler in ProcessBlock's MIDI drain section

## Feature 2: Terminal Trigger View

### Layout Restructure

Current canvas layout:
```
┌─────────────────────────────┐
│   Generative Geometry +     │
│   GOD Title (full canvas)   │
│                             │
│   Terminal Event Log         │
└─────────────────────────────┘
```

New layout:
```
┌─────────────────────────────┐
│ GOD Title + Geometry (compact strip) │
├─────────────────────────────┤
│                             │
│   Trigger Matrix View       │
│   (multi-track piano roll)  │
│                             │
├─────────────────────────────┤
│ Terminal Event Log (crystal) │
└─────────────────────────────┘
```

When no pads have hits and none are armed: geometry expands to full canvas (current behavior).

### Trigger Matrix View

A monospace, terminal-aesthetic multi-track view of the loop.

**Row visibility:**
- Only pads with hits (`!layer.hits.isEmpty`) or in red state (`layer.state == .red`) get rows
- Rows appear dynamically when a pad gets armed or gains hits
- Rows fade out (short animation) when a pad is cleared and has no hits — prevents layout thrashing during rapid clear/re-arm

**Row structure:**
```
 KICKS  ╸━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸
         ◆           ◆           ◆           ◆
 SNARE  ╸━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸
                 ◇           ◇           ◇           ◇
 HATS   ╸━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸
         ·   ·   ·   ·   ·   ·   ·   ·   ·   ·   ·   ·
```

**Pad name:** displayed on the left of each row (from `padBank.pads[i].name`).

**Hit characters by velocity:**
- `◆` — full velocity (≥100), solid crystal
- `◇` — medium velocity (40–99), hollow crystal
- `·` — ghost notes (<40), subtle dot

**Hit colors by crystal state:**
- **Red (armed):** hits appear in red (#d4564e) as they're played in live
- **Alive:** hits in orange (#da7b4a)
- Hit characters flash bright white momentarily when the cursor crosses them (triggered)

**Beat markers:** thin vertical lines or pipe characters in ice blue (#64beff) at each beat boundary.

**Playback cursor:** bright white vertical line sweeping left-to-right with the loop position. Pulses/flashes when crossing a hit.

### Swing Visualization

When swing is applied to a pad, that row's off-beat hits visually shift right in real-time. The grid breathes — you see the shuffle as you turn the knob. Hits are rendered at their swung positions (matching what you hear).

### Live Recording Visualization

When a pad is in red state and you play hits:
- Hits appear immediately as red crystals at their positions
- When the loop wraps and the pad transitions to alive, the crystals shift from red to orange

### BPM / Bar Count Scaling

- Hit x-positions are calculated as: `x = (hit.frame / loopLengthFrames) * viewWidth`
- When BPM or bar count changes, `loopLengthFrames` changes
- The grid rescales — hits maintain their musical position
- Beat markers reposition accordingly

### Data Flow

- View reads from `engine.layers[]` (published, main thread)
- Current position from `engine.transport.position` (synced at ~33Hz via existing UI throttle)
- No new data structures needed — reads the same hit arrays ProcessBlock uses
- SwiftUI view redraws on position/layer changes

### Shared Swing Utility

The swing math (sixteenth-note classification + offset calculation) is extracted into a shared static function usable by both ProcessBlock (audio thread) and the trigger view (main thread):

```swift
static func swungPosition(hitFrame: Int, swing: Float, sixteenthLength: Int, loopLength: Int) -> Int
```

This avoids duplicating the classification logic in two places.

### Hit Density

For dense patterns (many hits close together), higher velocity wins the display slot. At 4 bars / 120 BPM there are 64 sixteenth-note columns — enough resolution for most patterns. Sub-sixteenth ghost notes render at their exact pixel position, not snapped to grid.

### Terminal Event Log — Crystal Treatment

The existing terminal event log gets a color refresh to match the crystalline aesthetic:
- **System messages:** ice blue (#64beff)
- **Musical events (hits, state changes):** orange (#da7b4a) for alive, red (#d4564e) for armed
- **Structure/labels:** crystal white with high contrast
- **Background:** existing canvas dark (#131210)
- Overall: clean, legible, mineral clarity — light through quartz

## What Does NOT Change

- Hit storage format (`[Hit]` with frame + velocity, binary-search sorted)
- Crystal state machine (clear → red → alive)
- ProcessBlock structure (swing is an expanded-range scan + post-filter in the existing hit scan)
- MIDI input flow
- Capture system (still records stereo master with live effects)
- Existing per-pad filter/volume/pan controls and CC mappings
- Metronome
- Sample loading / pad bank

## CC Mapping Summary (Updated)

| CC  | Function           |
|-----|--------------------|
| 74  | Pad volume         |
| 71  | Pan                |
| 76  | HP cutoff          |
| 77  | LP cutoff          |
| 82  | Master volume      |
| 114 | Pad select encoder |
| 18  | **Pad swing (new)**|

## Keyboard Controls (New)

- `V`: increase active pad's swing by 0.01
- `Shift+V`: decrease active pad's swing by 0.01

## Edge Cases

**BPM changes with active swing:** When BPM changes, `loopLengthFrames` and `sixteenthLengthFrames` change. Stored hit positions (frame-based) no longer align to the new sixteenth grid. The swing classification recomputes against the new grid — hits may shift which slot they're nearest to. This is accepted behavior; swing is a live performance tool, not a precise editor. If the user changes BPM significantly, they can re-record.

**Swing at loop boundary:** A swung hit near the end of the loop wraps via modulo: `swungFrame % loopLengthFrames`. The wrap-aware scan in ProcessBlock already handles split-range queries — the expanded scan range simply extends this pattern.

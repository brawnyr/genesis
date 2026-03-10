# Per-Layer Effects & Active Pad Targeting

## Summary

Add per-layer effects (HP filter, LP filter, pan, volume) controlled by MiniLab 3 knobs, with automatic targeting based on the last played pad. Play a pad → knobs now control that pad's parameters.

## Knob Mapping

CC 14–17 control parameters for the **active pad** (last pad hit via MIDI noteOn).

| Knob | CC | Parameter | CC 0 | CC 64 | CC 127 |
|------|-----|-----------|-------|-------|--------|
| 1 | 14 | Volume | Silent | ~50% | Full |
| 2 | 15 | Pan | Hard left | Center | Hard right |
| 3 | 16 | HP Cutoff | 20Hz (clean) | ~1kHz | 20kHz (cuts everything) |
| 4 | 17 | LP Cutoff | 20Hz (cuts everything) | ~1kHz | 20kHz (clean) |

CCs 18–21 are unmapped (reserved for future use).

### Defaults (no knob touched)
- Volume: 127 (full)
- Pan: 64 (center)
- HP Cutoff: 0 (20Hz — no effect)
- LP Cutoff: 127 (20kHz — no effect)

## Signal Chain (per voice)

```
Sample playback
    ↓
HP Filter (biquad, 12dB/oct)
    ↓
LP Filter (biquad, 12dB/oct)
    ↓
Pan (stereo balance)
    ↓
Volume
    ↓
Mixed into master L/R output
```

## Active Pad Targeting

- `activePadIndex` tracked in GodEngine, set on every noteOn
- All 4 CC messages (14–17) apply to `activePadIndex`'s layer
- No pages, no modes — just play a pad and knobs target it

## Data Model

### Layer (new fields)
```swift
pan: Float = 0.5          // 0.0 = left, 0.5 = center, 1.0 = right
hpCutoff: Float = 20.0    // Hz, default = no effect
lpCutoff: Float = 20000.0 // Hz, default = no effect
```

### New: Biquad struct
- Coefficients: b0, b1, b2, a1, a2
- State: 2 samples of history (z1, z2)
- `process(inout [Float], count: Int)` — runs filter in-place
- Static methods: `lowPass(cutoff:sampleRate:)`, `highPass(cutoff:sampleRate:)`
- Standard 12dB/oct (2-pole) biquad

### Voice (new fields)
```swift
hpState: BiquadState  // per-voice filter memory
lpState: BiquadState
pan: Float
```

Each voice gets its own filter state so overlapping hits don't share filter memory.

## CC Handling Change

Current: CC number maps to a layer index (CC 14 → layer 0 volume, CC 15 → layer 1 volume, etc.)

New: CC number maps to a parameter of the active layer:
- CC 14 → active layer volume
- CC 15 → active layer pan
- CC 16 → active layer HP cutoff
- CC 17 → active layer LP cutoff

## Frequency Mapping

CC values (0–127) map to frequency using an exponential curve (linear CC → log frequency):

```
freq = 20 * (1000 ^ (cc / 127))
```

This gives ~20Hz at CC 0 and ~20kHz at CC 127, with musically useful distribution across the range.

## Pan Implementation

Equal-power panning (constant loudness across the stereo field):
```
left  *= cos(pan * π/2)
right *= sin(pan * π/2)
```

Where pan is 0.0 (full left) to 1.0 (full right), 0.5 = center.

## UI Changes

- Highlight the active pad in the channel list (e.g., blue dot or accent)
- Optional: show current parameter values for active pad

## Scope

- 4 parameters only: volume, pan, HP cutoff, LP cutoff
- 12dB/oct biquad filters (single stage)
- No slopes, no dirt, no additional effects
- CCs 18–21 reserved for future expansion

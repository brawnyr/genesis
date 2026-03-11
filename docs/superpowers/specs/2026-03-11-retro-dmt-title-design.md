# Retro DMT Generative Title — Design Spec

## Goal

Replace the pixel-art "GOD" bitmap title in `CanvasView.swift` with a sharp, chaotic generative geometric field. The title should be completely illegible — no letters, no words. Pure sacred geometry meets CRT monitor. Da Vinci on acid listening to cyberpunk.

## Aesthetic

- **Sharp, not soft.** Crisp edges, hard angles, thin strokes (1-2pt). No blur, no glow, no rounded anything.
- **Retro DMT.** Impossible symmetries that build then break apart. Nested geometric shapes. Angular spirals. Intersecting lines. Triangles, hexagons, sharp fragments.
- **Chaotic but structured.** Patterns start forming symmetry then glitch/shatter. Shapes mirror briefly then snap to new positions.
- **Layered depth.** Shapes at different opacity levels create a sense of looking *into* something.
- **CRT jitter.** Some shapes vibrate/jitter in place at high frequency — retro monitor feel.

## Architecture

### What changes

- `GodTitleLayer` in `CanvasView.swift` — replace the pixel bitmap Canvas rendering with the new generative field
- `Theme.godBitmap` in `Theme.swift` — remove (no longer used)
- `DriftPixel` struct — remove (replaced by new shape primitives)

### What stays

- The three color modes: idle (ice/white), playing (orange), god mode (orange+red)
- The underline below the title area
- Status text ("GENESIS ON DISK", "[space]", armed/recording)
- Master volume ring
- Transport info (BPM, bars, metro, beat)
- The `TimelineView` animation pattern at ~30fps
- The `Canvas` drawing context approach

### New data model

```swift
struct GeoShape {
    let kind: ShapeKind         // triangle, hexagon, line, angularSpiral, fragment
    let center: CGPoint         // position relative to canvas center
    let size: Double            // bounding size
    let rotation: Double        // initial rotation angle
    let rotationSpeed: Double   // radians per second
    let opacity: Double         // base opacity (0.1-0.8 for depth layering)
    let jitter: Double          // vibration amplitude (0 = still, >0 = CRT jitter)
    let lifespan: Double        // seconds before reshuffling
    let birthTime: Double       // creation timestamp
    let mirror: Bool            // if true, draw mirrored copy
}

enum ShapeKind: CaseIterable {
    case triangle
    case hexagon
    case line
    case angularSpiral
    case fragment              // shattered polygon piece
}
```

### Shape rendering

Each shape draws as a thin stroked path (no fill). The Canvas render loop:

1. Calculate age of each shape (`t - birthTime`)
2. Shapes fade in over 0.3s, hold, fade out over 0.3s before lifespan ends
3. Apply rotation: `initialRotation + age * rotationSpeed`
4. Apply jitter: offset position by `sin(t * highFreq) * jitterAmplitude`
5. If `mirror`, draw the shape again reflected across the vertical center axis
6. Respawn shapes that exceed their lifespan with new random parameters

### Shape generation

- Pool of ~25-40 shapes active at any time
- Each shape gets random kind, position (clustered toward center), size (10-60pt), rotation speed, opacity, jitter
- Position distribution: gaussian-ish, dense in center, sparse at edges
- Some shapes are large and slow (background), some small and fast (foreground)

### Color modes (same three states)

| State | Colors | Density | Speed |
|-------|--------|---------|-------|
| Idle | ice + white (0.4 opacity) | ~25 shapes, slow rotation | Simmering, calm jitter |
| Playing | orange + white (0.6 opacity) | ~35 shapes, medium rotation | Active, moderate jitter |
| God mode | orange + red (0.8 opacity) | ~40 shapes, fast rotation, max jitter | Chaotic, near-strobing fragments |

### Shape path generation

- **Triangle:** 3-point path, equilateral-ish with slight randomness in vertex positions
- **Hexagon:** 6-point regular polygon
- **Line:** single straight stroke at random angle, varying length
- **Angular spiral:** series of connected line segments spiraling outward with sharp turns (not smooth curves)
- **Fragment:** 3-5 point irregular polygon (like a shard of broken glass)

## Scope

- Single file change: `CanvasView.swift` (replace GodTitleLayer internals)
- Remove `godBitmap` from `Theme.swift`
- Remove `DriftPixel` struct from `CanvasView.swift`
- Remove `ambientPixels` state from `GodTitleLayer`
- No new files needed
- No test changes needed (visual only, no testable logic extracted)

## What this is NOT

- Not a particle system — shapes are geometric primitives, not dots
- Not smooth/organic — everything is angular and sharp
- Not readable — no letters, no text shapes, pure abstraction
- Not a music visualizer — doesn't react to audio levels (color mode changes with transport state only)

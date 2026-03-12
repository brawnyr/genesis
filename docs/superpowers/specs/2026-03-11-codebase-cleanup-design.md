# GOD Codebase Cleanup — Design Spec

**Date:** 2026-03-11
**Status:** Approved

## Goal

Restructure the GOD codebase so every file has one clear responsibility, no file exceeds ~300 lines, and the architecture makes it obvious where future capabilities (plugins, effects, new input sources) slot in. All changes are mechanical extractions — no behavioral changes, no API changes, tests remain unchanged.

## Principles

- Every file has one reason to exist
- Boundaries should make it obvious where new things go
- Don't touch what's already clean
- No behavioral changes — same public APIs, same test suite

## Extractions

### PadStripView.swift (640 -> ~6 files)

Currently contains 7+ unrelated views. Extract:

- **PadCell.swift** (~120 lines) — single pad visual cell with sample name, folder, signal level, breathing animation
- **PadCellOverlay.swift** (~50 lines) — glow strokes, top border, pending state blinking (already a ViewModifier)
- **MarqueeText.swift** (~50 lines) — smooth scrolling text overlay, reusable component
- **CCPanelView.swift** (~180 lines) — right-side inspector panel showing sample info, parameters (vol/pan/HP/LP), mode badges. InspectorRow, TcpsBadge, ToggleModeBadge helper views move here as they're only used by this panel
- **SampleBrowserView.swift** (~80 lines) — file list browser overlay with W/S navigation, Enter to load, T/ESC to close
- **PadStripView.swift** (~100 lines) — remains as the 8-cell strip layout + LoopProgressBar (LoopProgressBar stays here as it's ~5 lines and only used by this view)

### CanvasView.swift (449 -> 4 files)

Three distinct visual layers composed together. Extract:

- **PadVisualsLayer.swift** (~80 lines) — 8 columns with orange gradient intensity visualization
- **GodTitleLayer.swift** (~250 lines) — retro DMT generative field (triangles, hexagons, lines, spirals, fragments), CRT jitter, master volume ring, BPM/bars text
- **TerminalTextLayer.swift** (~80 lines) — terminal log display with blinking cursor, timestamped color-coded lines
- **CanvasView.swift** (~80 lines) — composes the three layers via ZStack

### ContentView.swift (418 -> 2 files)

ContentView lives at `GOD/GOD/ContentView.swift` (not in Views/) and stays there. Layout and keyboard handling are separate concerns:

- **ContentView+KeyHandlers.swift** (~220 lines) — extension with all key dispatch logic for normal/bpm/browse modes. `bpmPresets` array moves here since it's only used by `handleBPMKey`.
- **ContentView.swift** (~200 lines) — layout composition, state management, `KeyCaptureView`/`KeyCaptureRepresentable` (AppKit bridging, ~35 lines), `KeyLabel` helper view

### GodEngine.swift (583 -> ~4 files)

The engine currently handles coordination AND DSP AND CC routing AND transport control:

- **VoiceMixer.swift** (~80 lines) — pure DSP unit. Signature: `static func mix(voices: inout [Voice], layers: [Layer], cachedHP: [BiquadCoefficients?], cachedLP: [BiquadCoefficients?], into bufferL: inout [Float], bufferR: inout [Float], frameOffset: Int, count: Int) -> [Float]` — returns per-pad peak levels. Owns the voice iteration, `voice.fill()` calls, and peak tracking. Does not own the voice array or coefficient caching — the engine passes those in.
- **CCRouter.swift** (~80 lines) — CC routing with action closures. Captures a weak engine reference. Maps CC numbers to handler closures (e.g., `82: { engine, val in engine.setMasterVolume(val) }`). Handles main-thread dispatch internally where needed. The engine calls `router.handle(cc:, value:)` instead of a switch/case.
- **GodEngine+ProcessBlock.swift** (~120 lines) — the render callback, using VoiceMixer and CCRouter. Note: fields accessed by processBlock (e.g., `audio`, `voices`, `pendingLevels`, `cachedHPCoeffs`, etc.) must be `internal` rather than `private` to allow cross-file extension access.
- **GodEngine.swift** (~300 lines) — coordination hub: owns state, public API, transport control, delegates DSP to VoiceMixer and CC handling to CCRouter. `ToggleMode` and `VelocityMode` enums remain here (they're engine state consumed by views via @Published).

### EngineEventInterpreter.swift (228 -> 2 files)

Currently does two unrelated things — formatting log text and tracking visual decay for pad animations:

- **TerminalLogger.swift** (~130 lines) — event formatting, state diffing, line management. Consumed by TerminalTextLayer. Static formatting helpers (`formatPan`, `formatFrequency`, `formatDuration`) stay here as static methods — views import TerminalLogger for formatting, which is acceptable (they're display formatters, not logging internals).
- **PadIntensityTracker.swift** (~100 lines) — visual decay/sustain tracking for pad columns. Consumed by PadVisualsLayer.

## Naming & Pattern Pass

- Audit Theme.swift: ensure no color or font constants are hardcoded elsewhere. One source of truth.
- Helper views (InspectorRow, InspectorSectionHeader, TcpsBadge, ToggleModeBadge) don't need renaming — moving them to CCPanelView.swift gives them proper context.
- No gratuitous renames. If a name is clear in context and the file is in the right place, leave it.

## What Won't Change

- **Audio thread safety patterns** — dual-state design, OSMemoryBarrier, DispatchQueue.main.async sync
- **MIDIManager / MIDIRingBuffer** — clean, focused, right-sized
- **Transport / Sample / Layer / Voice / Metronome / Biquad** — all under 130 lines, single-purpose
- **BPMDetector** — 91 lines, self-contained DSP
- **GODApp.swift** — 187 lines, one-time init tasks, fine as-is
- **KeyReferenceOverlay / TransportView** — already clean
- **Test files** — public APIs don't change, tests stay the same

## Final File Map

```
Models/          (unchanged)
  Transport, Sample, Pad, Layer, Voice, Biquad, Metronome, GodCapture

Engine/
  GodEngine.swift              (~300 lines — coordination, state, public API)
  GodEngine+ProcessBlock.swift (~120 lines — render callback)
  VoiceMixer.swift             (~80 lines — DSP mixing/filtering)
  CCRouter.swift               (~80 lines — CC mapping with action closures)
  AudioManager.swift           (unchanged)
  MIDIManager.swift            (unchanged)
  MIDIRingBuffer.swift         (unchanged)
  TerminalLogger.swift         (~130 lines — event formatting)
  PadIntensityTracker.swift    (~100 lines — visual decay state)
  BPMDetector.swift            (unchanged)

ContentView.swift              (~200 lines — layout, state, AppKit bridging)
ContentView+KeyHandlers.swift  (~220 lines — key dispatch extension)

Views/
  Theme.swift                  (unchanged, audit for scattered constants)
  CanvasView.swift             (~80 lines — composes three layers)
  PadVisualsLayer.swift        (~80 lines)
  GodTitleLayer.swift          (~250 lines — generative animation)
  TerminalTextLayer.swift      (~80 lines)
  PadStripView.swift           (~100 lines — strip layout + progress bar)
  PadCell.swift                (~120 lines)
  PadCellOverlay.swift         (~50 lines)
  MarqueeText.swift            (~50 lines)
  CCPanelView.swift            (~180 lines — inspector + helpers)
  SampleBrowserView.swift      (~80 lines)
  TransportView.swift          (unchanged)
  KeyReferenceOverlay.swift    (unchanged)

GODApp.swift                   (unchanged)
```

## Success Criteria

- No file over ~300 lines
- Every file has one clear job
- `swift test` passes with no changes to test files
- `./bundle.sh --run` builds and launches correctly
- Extractions done file-by-file with build check after each to isolate any compilation errors
- No behavioral changes — identical functionality
- Future capabilities (plugins, effects, CC remapping) have obvious homes

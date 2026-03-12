# Codebase Cleanup Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the GOD codebase so every file has one clear responsibility, no file exceeds ~300 lines, and the architecture makes it obvious where future capabilities slot in. All changes are mechanical extractions — no behavioral changes, no API changes, tests remain unchanged.

**Architecture:** Extract views, layers, key handlers, DSP, and intensity tracking into focused single-responsibility files. Rename EngineEventInterpreter to TerminalLogger. Audit theme constants. No new dependencies.

**Tech Stack:** Swift, SwiftUI, Swift Testing. Build: `cd ~/god/GOD && swift build`. Test: `cd ~/god/GOD && swift test`.

**Pre-existing state:** 88/89 tests pass. `engineActivePadTracking` has a pre-existing failure. Do not break any currently-passing tests.

**Design spec:** `docs/superpowers/specs/2026-03-11-codebase-cleanup-design.md`

---

## Task 1: Extract MarqueeText from PadStripView

**Files:**
- Create: `GOD/GOD/Views/MarqueeText.swift`
- Modify: `GOD/GOD/Views/PadStripView.swift`

- [ ] **Step 1: Create MarqueeText.swift**

Create `GOD/GOD/Views/MarqueeText.swift` with `import SwiftUI`. Copy lines 35-101 from PadStripView.swift (the `MarqueeText` struct) into this file.

- [ ] **Step 2: Remove MarqueeText from PadStripView.swift**

Delete lines 35-101 (the `MarqueeText` struct) from PadStripView.swift. Same module, no import needed.

- [ ] **Step 3: Build check**

```bash
cd ~/god/GOD && swift build
```

---

## Task 2: Extract PadCellOverlay from PadStripView

**Files:**
- Create: `GOD/GOD/Views/PadCellOverlay.swift`
- Modify: `GOD/GOD/Views/PadStripView.swift`

- [ ] **Step 1: Create PadCellOverlay.swift**

Create `GOD/GOD/Views/PadCellOverlay.swift` with `import SwiftUI`. Copy lines 105-169 from PadStripView.swift (the `PadCellOverlay` ViewModifier) into this file.

- [ ] **Step 2: Remove PadCellOverlay from PadStripView.swift**

Delete lines 105-169 (the `PadCellOverlay` ViewModifier) from PadStripView.swift.

- [ ] **Step 3: Build check**

```bash
cd ~/god/GOD && swift build
```

---

## Task 3: Extract PadCell from PadStripView

**Files:**
- Create: `GOD/GOD/Views/PadCell.swift`
- Modify: `GOD/GOD/Views/PadStripView.swift`

- [ ] **Step 1: Create PadCell.swift**

Create `GOD/GOD/Views/PadCell.swift` with `import SwiftUI`. Copy lines 171-274 from PadStripView.swift (the `PadCell` struct) into this file. It references `MarqueeText` and `PadCellOverlay` which are now in their own files — same module, no import needed.

- [ ] **Step 2: Remove PadCell from PadStripView.swift**

Delete lines 171-274 (the `PadCell` struct) from PadStripView.swift.

- [ ] **Step 3: Build check**

```bash
cd ~/god/GOD && swift build
```

---

## Task 4: Extract SampleBrowserView from PadStripView

**Files:**
- Create: `GOD/GOD/Views/SampleBrowserView.swift`
- Modify: `GOD/GOD/Views/PadStripView.swift`

- [ ] **Step 1: Create SampleBrowserView.swift**

Create `GOD/GOD/Views/SampleBrowserView.swift` with:
```swift
import SwiftUI
import UniformTypeIdentifiers
import os

private let logger = Logger(subsystem: "com.god.ui", category: "PadStrip")
```

Copy lines 509-638 from PadStripView.swift (the `SampleBrowserView` and any helper types it uses) into this file.

- [ ] **Step 2: Remove SampleBrowserView from PadStripView.swift**

Delete lines 509-638 from PadStripView.swift.

- [ ] **Step 3: Build check**

```bash
cd ~/god/GOD && swift build
```

---

## Task 5: Extract CCPanelView from PadStripView

**Files:**
- Create: `GOD/GOD/Views/CCPanelView.swift`
- Modify: `GOD/GOD/Views/PadStripView.swift`

- [ ] **Step 1: Create CCPanelView.swift**

Create `GOD/GOD/Views/CCPanelView.swift` with `import SwiftUI`. Copy the following from PadStripView.swift:
- `InspectorSectionHeader` (lines 304-319)
- `InspectorRow` (lines 321-346)
- `TcpsBadge` (lines 348-377)
- `ToggleModeBadge` (lines 379-407)
- `CCPanelView` (lines 411-505)

- [ ] **Step 2: Remove extracted types from PadStripView.swift**

Delete all five types listed above from PadStripView.swift.

- [ ] **Step 3: Verify PadStripView.swift is clean**

After this extraction, PadStripView.swift should contain only: the logger, `PadStripView` struct, and `LoopProgressBar` struct (~55 lines total).

- [ ] **Step 4: Build check**

```bash
cd ~/god/GOD && swift build
```

---

## Task 6: Extract CanvasView layers

**Files:**
- Create: `GOD/GOD/Views/PadVisualsLayer.swift`
- Create: `GOD/GOD/Views/GodTitleLayer.swift`
- Create: `GOD/GOD/Views/TerminalTextLayer.swift`
- Modify: `GOD/GOD/Views/CanvasView.swift`

- [ ] **Step 1: Create PadVisualsLayer.swift**

Create `GOD/GOD/Views/PadVisualsLayer.swift` with `import SwiftUI`. Copy lines 38-69 from CanvasView.swift (the `PadVisualsLayer` view).

- [ ] **Step 2: Create GodTitleLayer.swift**

Create `GOD/GOD/Views/GodTitleLayer.swift` with `import SwiftUI`. Copy lines 73-381 from CanvasView.swift (includes `GeoShapeKind` enum, `GeoShape` struct, and `GodTitleLayer` view).

- [ ] **Step 3: Create TerminalTextLayer.swift**

Create `GOD/GOD/Views/TerminalTextLayer.swift` with `import SwiftUI`. Copy lines 385-448 from CanvasView.swift (the `TerminalTextLayer` view). It references `LineKind` which is defined in EngineEventInterpreter.swift — same module, no import needed.

- [ ] **Step 4: Remove layers from CanvasView.swift**

Delete lines 38-448 from CanvasView.swift. CanvasView.swift should end up as just the `CanvasView` struct (~34 lines) with `import SwiftUI`.

- [ ] **Step 5: Build check**

```bash
cd ~/god/GOD && swift build
```

---

## Task 7: Extract ContentView key handlers

**Files:**
- Create: `GOD/GOD/ContentView+KeyHandlers.swift`
- Modify: `GOD/GOD/ContentView.swift`

- [ ] **Step 1: Adjust access modifiers in ContentView.swift**

Swift extensions in separate files cannot access `private` members. Make the following changes in ContentView.swift:
- Remove `private` from `EditMode` enum (make it `internal`)
- The `Key` enum (lines 137-162) will move to the extension file as a non-private enum
- The `@State` vars (`mode`, `browserIndex`, `bpmInput`, `bpmPresetIndex`, `showKeyReference`) are already internal by default since they have no access modifier — verify this is the case

- [ ] **Step 2: Create ContentView+KeyHandlers.swift**

Create `GOD/GOD/ContentView+KeyHandlers.swift` containing an `extension ContentView` with:
- The `Key` enum (lines 137-162) — as `internal` (not private)
- `bpmPresets` array (lines 54-74) — as a static property on the extension
- `padName()` (lines 164-166)
- `loadBrowserSample()` (lines 168-185)
- `browserFileName()` (lines 187-196)
- `handleKey()` (lines 198-207)
- `handleBPMKey()` (lines 209-249)
- `handleBrowseKey()` (lines 251-275)
- `handleNormalKey()` (lines 277-399)

All methods that were `private` must become `internal` (or at minimum not marked `private`) since they're in a separate file.

- [ ] **Step 3: Remove extracted code from ContentView.swift**

Delete the Key enum, bpmPresets array, and all key handler methods from ContentView.swift. ContentView.swift keeps: `KeyCaptureView`, `KeyCaptureRepresentable`, the `ContentView` struct with body and state vars, and `KeyLabel` (~200 lines).

- [ ] **Step 4: Build check**

```bash
cd ~/god/GOD && swift build
```

---

## Task 8: Extract PadIntensityTracker from EngineEventInterpreter

**Files:**
- Create: `GOD/GOD/Engine/PadIntensityTracker.swift`
- Modify: `GOD/GOD/Engine/EngineEventInterpreter.swift`
- Modify: `GOD/GOD/Engine/GodEngine.swift`
- Modify: `GOD/GOD/GODApp.swift`
- Modify: `GOD/GOD/Views/PadStripView.swift`
- Modify: `GOD/GOD/Views/CanvasView.swift` (or `GOD/GOD/Views/PadVisualsLayer.swift` after Task 6)

- [ ] **Step 1: Create PadIntensityTracker.swift**

Create `GOD/GOD/Engine/PadIntensityTracker.swift` containing a new `PadIntensityTracker` class (ObservableObject) with:
- `@Published var padIntensities: [Float]` — initialized to `Array(repeating: 0, count: PadBank.padCount)`
- The decay constants: `shortDecay`, `sustainDecay`, `sustainMinIntensity`, `intensityCutoff`
- `var activePadVoices: Set<Int>` — initialized to empty set
- `func tickVisuals()` — the visual decay logic (lines 182-194 from EngineEventInterpreter)
- `func triggerPad(_ index: Int, velocity: Float)` — sets intensity to velocity-normalized value

- [ ] **Step 2: Remove intensity tracking from EngineEventInterpreter**

In EngineEventInterpreter.swift, remove:
- `@Published var padIntensities` — moves to PadIntensityTracker
- `activePadVoices` — moves to PadIntensityTracker
- `tickVisuals()` — moves to PadIntensityTracker
- Decay constants (`shortDecay`, `sustainDecay`, `sustainMinIntensity`, `intensityCutoff`)
- In `processHits()`, remove the intensity update lines (engine will call `PadIntensityTracker.triggerPad` directly)
- In `processStateDiff()`, remove the intensity zeroing on mute (PadIntensityTracker handles this)

- [ ] **Step 3: Update GodEngine.swift**

- Add `var intensityTracker: PadIntensityTracker?`
- In the UI sync block, call `intensityTracker?.activePadVoices = activeVoicePads` and `intensityTracker?.tickVisuals()` instead of going through interpreter
- For hits, call `intensityTracker?.triggerPad(padIndex, velocity: velNorm)`

- [ ] **Step 4: Update GODApp.swift**

Create `PadIntensityTracker` as `@StateObject`, pass to engine and views.

- [ ] **Step 5: Update views**

- `PadStripView`: change `@ObservedObject var interpreter` to take `intensityTracker`, read `padIntensities` from it
- `PadVisualsLayer`: change `@ObservedObject var interpreter` to take `intensityTracker`
- `CanvasView`: pass `intensityTracker` instead of `interpreter` to `PadVisualsLayer`

- [ ] **Step 6: Build check**

```bash
cd ~/god/GOD && swift build
```

---

## Task 9: Rename EngineEventInterpreter to TerminalLogger

**Files:**
- Modify: `GOD/GOD/Engine/EngineEventInterpreter.swift` (rename file to `TerminalLogger.swift`)
- Modify: `GOD/GOD/Engine/GodEngine.swift`
- Modify: `GOD/GOD/GODApp.swift`
- Modify: `GOD/GOD/ContentView.swift`
- Modify: `GOD/GOD/Views/CanvasView.swift` (or `GOD/GOD/Views/TerminalTextLayer.swift` after Task 6)

- [ ] **Step 1: Rename the class**

In `EngineEventInterpreter.swift`, rename the class from `EngineEventInterpreter` to `TerminalLogger`.

- [ ] **Step 2: Rename the file**

```bash
cd ~/god && git mv GOD/GOD/Engine/EngineEventInterpreter.swift GOD/GOD/Engine/TerminalLogger.swift
```

- [ ] **Step 3: Update all references**

Find and replace `EngineEventInterpreter` with `TerminalLogger` in:
- `GodEngine.swift`
- `GODApp.swift`
- `ContentView.swift`
- `TerminalTextLayer.swift` (or `CanvasView.swift` if Task 6 hasn't run yet)

- [ ] **Step 4: Build check**

```bash
cd ~/god/GOD && swift build
```

---

## Task 10: Extract VoiceMixer from GodEngine

**Files:**
- Create: `GOD/GOD/Engine/VoiceMixer.swift`
- Modify: `GOD/GOD/Engine/GodEngine.swift` (or `GOD/GOD/Engine/GodEngine+ProcessBlock.swift` if Task 11 runs after)

- [ ] **Step 1: Create VoiceMixer.swift**

Create `GOD/GOD/Engine/VoiceMixer.swift` with a stateless enum:

```swift
enum VoiceMixer {
    static func mix(
        voices: inout [Voice],
        layers: [Layer],
        cachedHP: [BiquadCoefficients],
        cachedLP: [BiquadCoefficients],
        intoLeft bufferL: inout [Float],
        intoRight bufferR: inout [Float],
        count: Int
    ) -> [Float] {
        var levels = [Float](repeating: 0, count: PadBank.padCount)
        voices = voices.compactMap { voice in
            var v = voice
            let padIdx = v.padIndex
            let hpCoeffs = padIdx >= 0 && padIdx < PadBank.padCount ? cachedHP[padIdx] : .bypass
            let lpCoeffs = padIdx >= 0 && padIdx < PadBank.padCount ? cachedLP[padIdx] : .bypass
            let pan = padIdx >= 0 && padIdx < PadBank.padCount ? layers[padIdx].pan : 0.5
            let volume = padIdx >= 0 && padIdx < PadBank.padCount ? layers[padIdx].volume : 1.0
            let (done, peak) = v.fill(intoLeft: &bufferL, right: &bufferR, count: count,
                                       pan: pan, volume: volume, hpCoeffs: hpCoeffs, lpCoeffs: lpCoeffs)
            if padIdx >= 0 && padIdx < PadBank.padCount {
                levels[padIdx] = max(levels[padIdx], peak)
            }
            return done ? nil : v
        }
        return levels
    }
}
```

Note: VoiceMixer is an `enum` with a static method (no state) to keep it simple and value-semantic.

- [ ] **Step 2: Replace voice mixing block in processBlock**

In GodEngine's `processBlock`, replace the voice mixing block (lines 456-469) with:

```swift
let frameLevels = VoiceMixer.mix(
    voices: &voices, layers: audio.layers,
    cachedHP: cachedHPCoeffs, cachedLP: cachedLPCoeffs,
    intoLeft: &outputBufferL, intoRight: &outputBufferR, count: frameCount
)
for i in 0..<PadBank.padCount {
    pendingLevels[i] = max(pendingLevels[i], frameLevels[i])
}
```

`pendingLevels` accumulates across frames (zeroed each UI sync cycle), so the engine maxes per-call peaks into it.

- [ ] **Step 3: Build check**

```bash
cd ~/god/GOD && swift build
```

---

## Task 11: Extract GodEngine+ProcessBlock

**Files:**
- Create: `GOD/GOD/Engine/GodEngine+ProcessBlock.swift`
- Modify: `GOD/GOD/Engine/GodEngine.swift`

- [ ] **Step 1: Widen access modifiers in GodEngine.swift**

Change the following from `private` to `internal` so the extension file can access them:
- `audio` → `internal var audio`
- `outputBufferL`, `outputBufferR` → `internal`
- `cachedHPCutoffs`, `cachedLPCutoffs`, `cachedHPCoeffs`, `cachedLPCoeffs` → `internal`
- `pendingLevels`, `pendingTriggers`, `pendingHits` → `internal`
- `uiUpdateCounter` → `internal`
- Keep `voices` as `private(set) var` (already internal for get)

- [ ] **Step 2: Create GodEngine+ProcessBlock.swift**

Create `GOD/GOD/Engine/GodEngine+ProcessBlock.swift` containing `extension GodEngine` with:
- `func processBlock(frameCount: Int) -> (left: [Float], right: [Float])` (the full method)
- `func handlePadHit(note:velocity:record:)` (was private, now internal)
- `func handleNoteOff(note:)` (was private, now internal)
- `func handleCC(number:value:)` (was private, now internal)
- `func updateCachedCoefficients()` (was private, now internal)

Note: CCRouter extraction was dropped — the CC handling is only ~25 lines of tightly-coupled audio thread code that directly modifies `audio` state. Extracting it would require either passing audio state around or widening access modifiers for minimal benefit. It stays in `handleCC` within the processBlock extension.

- [ ] **Step 3: Remove extracted methods from GodEngine.swift**

Delete `processBlock`, `handlePadHit`, `handleNoteOff`, `handleCC`, and `updateCachedCoefficients` from GodEngine.swift.

- [ ] **Step 4: Build check**

```bash
cd ~/god/GOD && swift build
```

---

## Task 12: Run tests

- [ ] **Step 1: Run full test suite**

```bash
cd ~/god/GOD && swift test
```

Expected: 88/89 pass (same pre-existing failure in `engineActivePadTracking`). No regressions from any extraction.

---

## Task 13: Theme audit

**Files:**
- Modify: `GOD/GOD/Views/Theme.swift`
- Modify: `GOD/GOD/Views/CCPanelView.swift` (after Task 5)
- Modify: `GOD/GOD/ContentView.swift`
- Modify: `GOD/GOD/Views/PadCell.swift` (after Task 3)

- [ ] **Step 1: Identify hardcoded colors**

Check for hardcoded color/font constants outside Theme.swift. Known instances:
- `Color(red: 0.071, green: 0.067, blue: 0.059)` in CCPanelView (inspector background)
- `Color(red: 0.086, green: 0.082, blue: 0.075)` in ContentView (hotkeys strip background)
- `Color(white: 0.02)` and similar in PadCell

- [ ] **Step 2: Add named constants to Theme.swift**

Add any repeated hardcoded colors to Theme.swift as named static constants (e.g., `Theme.inspectorBg`, `Theme.stripBg`, `Theme.padBg`).

- [ ] **Step 3: Replace hardcoded colors with Theme references**

Update CCPanelView.swift, ContentView.swift, and PadCell.swift to use the new Theme constants.

- [ ] **Step 4: Build check**

```bash
cd ~/god/GOD && swift build
```

---

## Task 14: Update CODEBASE.md and CLAUDE.md

**Files:**
- Modify: `GOD/CODEBASE.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update CODEBASE.md**

Update CODEBASE.md to reflect all new file locations:
- New files: MarqueeText.swift, PadCellOverlay.swift, PadCell.swift, SampleBrowserView.swift, CCPanelView.swift, PadVisualsLayer.swift, GodTitleLayer.swift, TerminalTextLayer.swift, ContentView+KeyHandlers.swift, PadIntensityTracker.swift, VoiceMixer.swift, GodEngine+ProcessBlock.swift
- Renamed: EngineEventInterpreter → TerminalLogger
- Reduced: PadStripView.swift, CanvasView.swift, ContentView.swift, GodEngine.swift

- [ ] **Step 2: Update CLAUDE.md**

Update the project structure section to list all new files.

- [ ] **Step 3: Commit everything**

```bash
git add -A && git commit -m "refactor: codebase cleanup — extract responsibilities, sharpen boundaries"
```

---

## Task 15: Final verification

- [ ] **Step 1: Run tests**

```bash
cd ~/god/GOD && swift test
```

Expected: 88/89 pass (same pre-existing failure).

- [ ] **Step 2: Build**

```bash
cd ~/god/GOD && swift build
```

Expected: Builds successfully.

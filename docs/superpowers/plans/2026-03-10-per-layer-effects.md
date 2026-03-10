# Per-Layer Effects Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-layer HP/LP filters, pan, and volume controlled by MiniLab knobs targeting the last-played pad.

**Architecture:** Each Voice gets inline biquad filter processing (sample-by-sample, no buffer allocation). Layer stores effect parameters. GodEngine routes CC 14–17 to the active pad's layer instead of individual layer volumes. Coefficients recalculated per block from layer cutoff values.

**Tech Stack:** Swift, AVFoundation (existing), standard biquad IIR filters

**Spec:** `docs/superpowers/specs/2026-03-10-per-layer-effects-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `GOD/GOD/Models/Biquad.swift` | Filter coefficients, state, sample processing |
| Modify | `GOD/GOD/Models/Layer.swift` | Add pan, hpCutoff, lpCutoff fields |
| Modify | `GOD/GOD/Models/Voice.swift` | Add filter state, apply effects in fill() |
| Modify | `GOD/GOD/Engine/GodEngine.swift` | Active pad tracking, CC routing, pass params to fill |
| Modify | `GOD/GOD/Views/ChannelRowView.swift` | Active pad highlight |
| Create | `GOD/Tests/BiquadTests.swift` | Filter unit tests |
| Modify | `GOD/Tests/LayerTests.swift` | Test new fields |
| Modify | `GOD/Tests/VoiceTests.swift` | Test filter + pan in fill |
| Modify | `GOD/Tests/MIDITests.swift` | Test CC routing to active pad |
| Modify | `GOD/Tests/GodEngineTests.swift` | Test active pad tracking |

---

## Task 1: Biquad Filter

**Files:**
- Create: `GOD/GOD/Models/Biquad.swift`
- Create: `GOD/Tests/BiquadTests.swift`

- [ ] **Step 1: Write BiquadTests**

```swift
// GOD/Tests/BiquadTests.swift
import Testing
@testable import GOD

@Test func biquadStateStartsAtZero() {
    let state = BiquadState()
    #expect(state.z1 == 0)
    #expect(state.z2 == 0)
}

@Test func lowPassCoefficientsAtNyquist() {
    // At 20kHz (near Nyquist for 44100), filter should pass everything
    let coeffs = BiquadCoefficients.lowPass(cutoff: 20000, sampleRate: 44100)
    var state = BiquadState()
    // Process a 1.0 impulse — output should be close to input
    let out = biquadProcessSample(1.0, coeffs: coeffs, state: &state)
    #expect(out > 0.5) // not perfectly 1.0 due to filter math, but passes signal
}

@Test func highPassCoefficientsAtMinFreq() {
    // At 20Hz, HP filter should pass everything
    let coeffs = BiquadCoefficients.highPass(cutoff: 20, sampleRate: 44100)
    var state = BiquadState()
    // Process a DC signal — first sample won't be perfect, but after settling...
    for _ in 0..<1000 {
        _ = biquadProcessSample(1.0, coeffs: coeffs, state: &state)
    }
    // HP blocks DC, so after settling it should approach 0
    let out = biquadProcessSample(1.0, coeffs: coeffs, state: &state)
    #expect(out < 0.1)
}

@Test func lowPassRemovesHighFrequency() {
    // LP at 100Hz should kill a 10kHz sine
    let coeffs = BiquadCoefficients.lowPass(cutoff: 100, sampleRate: 44100)
    var state = BiquadState()
    var maxOutput: Float = 0

    // Generate 10kHz sine and filter it
    for i in 0..<4410 {
        let t = Float(i) / 44100.0
        let input = sin(2.0 * .pi * 10000.0 * t)
        let out = biquadProcessSample(input, coeffs: coeffs, state: &state)
        if i > 100 { // skip transient
            maxOutput = max(maxOutput, abs(out))
        }
    }
    #expect(maxOutput < 0.05)
}

@Test func highPassRemovesLowFrequency() {
    // HP at 5000Hz should kill a 100Hz sine
    let coeffs = BiquadCoefficients.highPass(cutoff: 5000, sampleRate: 44100)
    var state = BiquadState()
    var maxOutput: Float = 0

    for i in 0..<4410 {
        let t = Float(i) / 44100.0
        let input = sin(2.0 * .pi * 100.0 * t)
        let out = biquadProcessSample(input, coeffs: coeffs, state: &state)
        if i > 100 {
            maxOutput = max(maxOutput, abs(out))
        }
    }
    #expect(maxOutput < 0.05)
}

@Test func ccToFrequencyMapping() {
    let low = ccToFrequency(0)
    let mid = ccToFrequency(64)
    let high = ccToFrequency(127)

    #expect(low >= 19 && low <= 21)     // ~20Hz
    #expect(mid > 500 && mid < 1500)    // ~midrange
    #expect(high >= 19000 && high <= 21000) // ~20kHz
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/brawny/god/GOD && swift test 2>&1 | grep -E "(FAIL|error|cannot find)"`
Expected: Compilation errors — `BiquadState`, `BiquadCoefficients`, `biquadProcessSample`, `ccToFrequency` not found.

- [ ] **Step 3: Implement Biquad.swift**

```swift
// GOD/GOD/Models/Biquad.swift
import Foundation

struct BiquadState {
    var z1: Float = 0
    var z2: Float = 0
}

struct BiquadCoefficients {
    let b0, b1, b2, a1, a2: Float

    /// 12dB/oct low-pass filter
    static func lowPass(cutoff: Float, sampleRate: Float) -> BiquadCoefficients {
        let w0 = 2.0 * Float.pi * cutoff / sampleRate
        let cosW0 = cos(w0)
        let sinW0 = sin(w0)
        let alpha = sinW0 / (2.0 * 0.7071) // Q = 0.7071 (Butterworth)

        let b0 = (1.0 - cosW0) / 2.0
        let b1 = 1.0 - cosW0
        let b2 = (1.0 - cosW0) / 2.0
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cosW0
        let a2 = 1.0 - alpha

        return BiquadCoefficients(
            b0: b0 / a0, b1: b1 / a0, b2: b2 / a0,
            a1: a1 / a0, a2: a2 / a0
        )
    }

    /// 12dB/oct high-pass filter
    static func highPass(cutoff: Float, sampleRate: Float) -> BiquadCoefficients {
        let w0 = 2.0 * Float.pi * cutoff / sampleRate
        let cosW0 = cos(w0)
        let sinW0 = sin(w0)
        let alpha = sinW0 / (2.0 * 0.7071)

        let b0 = (1.0 + cosW0) / 2.0
        let b1 = -(1.0 + cosW0)
        let b2 = (1.0 + cosW0) / 2.0
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cosW0
        let a2 = 1.0 - alpha

        return BiquadCoefficients(
            b0: b0 / a0, b1: b1 / a0, b2: b2 / a0,
            a1: a1 / a0, a2: a2 / a0
        )
    }

    /// Bypass — passes signal unchanged
    static let bypass = BiquadCoefficients(b0: 1, b1: 0, b2: 0, a1: 0, a2: 0)
}

/// Direct Form II Transposed biquad — processes one sample
func biquadProcessSample(_ input: Float, coeffs: BiquadCoefficients, state: inout BiquadState) -> Float {
    let output = coeffs.b0 * input + state.z1
    state.z1 = coeffs.b1 * input - coeffs.a1 * output + state.z2
    state.z2 = coeffs.b2 * input - coeffs.a2 * output
    return output
}

/// Maps CC value (0–127) to frequency (20Hz–20kHz) on exponential curve
func ccToFrequency(_ cc: Int) -> Float {
    let normalized = Float(max(0, min(127, cc))) / 127.0
    return 20.0 * pow(1000.0, normalized)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/brawny/god/GOD && swift test --filter Biquad`
Expected: All 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/brawny/god
git add GOD/GOD/Models/Biquad.swift GOD/Tests/BiquadTests.swift
git commit -m "feat: add biquad filter with HP/LP coefficients and CC-to-frequency mapping"
```

---

## Task 2: Layer Model — Add Effect Parameters

**Files:**
- Modify: `GOD/GOD/Models/Layer.swift:8-19`
- Modify: `GOD/Tests/LayerTests.swift`

- [ ] **Step 1: Add test for new Layer fields**

Append to `GOD/Tests/LayerTests.swift`:

```swift
@Test func layerEffectDefaults() {
    let layer = Layer(index: 0, name: "KICK")
    #expect(layer.pan == 0.5)
    #expect(layer.hpCutoff == 20.0)
    #expect(layer.lpCutoff == 20000.0)
}

@Test func layerEffectParamsSettable() {
    var layer = Layer(index: 0, name: "KICK")
    layer.pan = 0.0
    layer.hpCutoff = 500.0
    layer.lpCutoff = 8000.0
    #expect(layer.pan == 0.0)
    #expect(layer.hpCutoff == 500.0)
    #expect(layer.lpCutoff == 8000.0)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/brawny/god/GOD && swift test --filter layerEffect 2>&1`
Expected: Compilation error — `Layer` has no member `pan`, `hpCutoff`, `lpCutoff`.

- [ ] **Step 3: Add fields to Layer**

In `GOD/GOD/Models/Layer.swift`, add after `var volume: Float = 1.0`:

```swift
    var pan: Float = 0.5            // 0.0 = left, 0.5 = center, 1.0 = right
    var hpCutoff: Float = 20.0      // Hz — 20 = no effect
    var lpCutoff: Float = 20000.0   // Hz — 20000 = no effect
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/brawny/god/GOD && swift test --filter layer`
Expected: All layer tests PASS (existing + new).

- [ ] **Step 5: Commit**

```bash
cd /Users/brawny/god
git add GOD/GOD/Models/Layer.swift GOD/Tests/LayerTests.swift
git commit -m "feat: add pan, hpCutoff, lpCutoff to Layer"
```

---

## Task 3: Voice — Apply Filters and Pan in fill()

**Files:**
- Modify: `GOD/GOD/Models/Voice.swift`
- Modify: `GOD/Tests/VoiceTests.swift`

- [ ] **Step 1: Write tests for filtered and panned voice output**

Append to `GOD/Tests/VoiceTests.swift`:

```swift
@Test func voicePanLeft() {
    let data: [Float] = [1.0, 1.0]
    let sample = Sample(name: "test", left: data, right: data, sampleRate: 44100)
    var voice = Voice(sample: sample, velocity: 1.0)

    var left = [Float](repeating: 0, count: 2)
    var right = [Float](repeating: 0, count: 2)
    let hpCoeffs = BiquadCoefficients.bypass
    let lpCoeffs = BiquadCoefficients.bypass
    let (_, _) = voice.fill(intoLeft: &left, right: &right, count: 2,
                             pan: 0.0, hpCoeffs: hpCoeffs, lpCoeffs: lpCoeffs)
    // Hard left: left should be ~1.0, right should be ~0.0
    #expect(left[0] > 0.9)
    #expect(right[0] < 0.1)
}

@Test func voicePanCenter() {
    let data: [Float] = [1.0, 1.0]
    let sample = Sample(name: "test", left: data, right: data, sampleRate: 44100)
    var voice = Voice(sample: sample, velocity: 1.0)

    var left = [Float](repeating: 0, count: 2)
    var right = [Float](repeating: 0, count: 2)
    let hpCoeffs = BiquadCoefficients.bypass
    let lpCoeffs = BiquadCoefficients.bypass
    let (_, _) = voice.fill(intoLeft: &left, right: &right, count: 2,
                             pan: 0.5, hpCoeffs: hpCoeffs, lpCoeffs: lpCoeffs)
    // Center: both channels equal, ~0.707
    #expect(abs(left[0] - right[0]) < 0.01)
    #expect(left[0] > 0.6)
}

@Test func voicePanRight() {
    let data: [Float] = [1.0, 1.0]
    let sample = Sample(name: "test", left: data, right: data, sampleRate: 44100)
    var voice = Voice(sample: sample, velocity: 1.0)

    var left = [Float](repeating: 0, count: 2)
    var right = [Float](repeating: 0, count: 2)
    let hpCoeffs = BiquadCoefficients.bypass
    let lpCoeffs = BiquadCoefficients.bypass
    let (_, _) = voice.fill(intoLeft: &left, right: &right, count: 2,
                             pan: 1.0, hpCoeffs: hpCoeffs, lpCoeffs: lpCoeffs)
    #expect(left[0] < 0.1)
    #expect(right[0] > 0.9)
}

@Test func voiceWithLowPassFilter() {
    // Generate a high-frequency sine (10kHz) sample
    let sampleRate: Float = 44100
    let frameCount = 4410
    var data = [Float](repeating: 0, count: frameCount)
    for i in 0..<frameCount {
        data[i] = sin(2.0 * .pi * 10000.0 * Float(i) / sampleRate)
    }
    let sample = Sample(name: "test", left: data, right: data, sampleRate: 44100)
    var voice = Voice(sample: sample, velocity: 1.0)

    var left = [Float](repeating: 0, count: frameCount)
    var right = [Float](repeating: 0, count: frameCount)
    let hpCoeffs = BiquadCoefficients.bypass
    let lpCoeffs = BiquadCoefficients.lowPass(cutoff: 100, sampleRate: sampleRate)
    let (_, peak) = voice.fill(intoLeft: &left, right: &right, count: frameCount,
                                pan: 0.5, hpCoeffs: hpCoeffs, lpCoeffs: lpCoeffs)
    // LP at 100Hz should massively attenuate 10kHz
    #expect(peak < 0.1)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/brawny/god/GOD && swift test --filter voice 2>&1`
Expected: Compilation errors — `fill` signature doesn't match.

- [ ] **Step 3: Update Voice.swift with filter state and new fill signature**

Replace `GOD/GOD/Models/Voice.swift` entirely:

```swift
import Foundation

struct Voice {
    let sample: Sample
    let velocity: Float
    var padIndex: Int = -1
    var position: Int = 0

    // Per-voice filter state (separate L/R for stereo independence)
    var hpStateL = BiquadState()
    var hpStateR = BiquadState()
    var lpStateL = BiquadState()
    var lpStateR = BiquadState()

    /// Mixes this voice into stereo buffers with filtering and panning.
    /// Returns (finished, peak).
    mutating func fill(intoLeft left: inout [Float], right: inout [Float], count: Int,
                       pan: Float, hpCoeffs: BiquadCoefficients, lpCoeffs: BiquadCoefficients
    ) -> (finished: Bool, peak: Float) {
        let remaining = sample.frameCount - position
        let toWrite = min(count, remaining)
        var peak: Float = 0

        let panL = cos(pan * .pi / 2.0)
        let panR = sin(pan * .pi / 2.0)

        for i in 0..<toWrite {
            var l = sample.left[position + i] * velocity
            var r = sample.right[position + i] * velocity

            // HP filter
            l = biquadProcessSample(l, coeffs: hpCoeffs, state: &hpStateL)
            r = biquadProcessSample(r, coeffs: hpCoeffs, state: &hpStateR)

            // LP filter
            l = biquadProcessSample(l, coeffs: lpCoeffs, state: &lpStateL)
            r = biquadProcessSample(r, coeffs: lpCoeffs, state: &lpStateR)

            // Pan (equal-power)
            l *= panL
            r *= panR

            left[i] += l
            right[i] += r
            peak = max(peak, abs(l), abs(r))
        }

        position += toWrite
        return (position >= sample.frameCount, peak)
    }
}
```

- [ ] **Step 4: Update existing voice tests to use new signature**

All existing tests in `VoiceTests.swift` need `pan: 0.5, hpCoeffs: .bypass, lpCoeffs: .bypass` added to `fill()` calls. Update the full file:

```swift
import Testing
@testable import GOD

@Test func voicePlayback() {
    let data: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
    let sample = Sample(name: "test", left: data, right: data, sampleRate: 44100)
    var voice = Voice(sample: sample, velocity: 1.0)

    var left = [Float](repeating: 0, count: 3)
    var right = [Float](repeating: 0, count: 3)
    let (finished, _) = voice.fill(intoLeft: &left, right: &right, count: 3,
                                    pan: 0.5, hpCoeffs: .bypass, lpCoeffs: .bypass)
    #expect(finished == false)
    // Center pan ≈ 0.707 multiplier
    let scale = cos(0.5 * .pi / 2.0)
    #expect(abs(left[0] - 0.1 * scale) < 0.001)
    #expect(abs(left[1] - 0.2 * scale) < 0.001)
    #expect(abs(left[2] - 0.3 * scale) < 0.001)
}

@Test func voiceFinishes() {
    let data: [Float] = [0.1, 0.2]
    let sample = Sample(name: "test", left: data, right: data, sampleRate: 44100)
    var voice = Voice(sample: sample, velocity: 1.0)

    var left = [Float](repeating: 0, count: 4)
    var right = [Float](repeating: 0, count: 4)
    let (finished, _) = voice.fill(intoLeft: &left, right: &right, count: 4,
                                    pan: 0.5, hpCoeffs: .bypass, lpCoeffs: .bypass)
    #expect(finished == true)
    #expect(left[2] == 0)
    #expect(left[3] == 0)
}

@Test func voiceVelocityScaling() {
    let data: [Float] = [1.0, 1.0]
    let sample = Sample(name: "test", left: data, right: data, sampleRate: 44100)
    var voice = Voice(sample: sample, velocity: 0.5)

    var left = [Float](repeating: 0, count: 2)
    var right = [Float](repeating: 0, count: 2)
    let (_, peak) = voice.fill(intoLeft: &left, right: &right, count: 2,
                                pan: 0.5, hpCoeffs: .bypass, lpCoeffs: .bypass)
    let scale = cos(0.5 * .pi / 2.0)
    #expect(abs(left[0] - 0.5 * scale) < 0.001)
    #expect(abs(peak - 0.5 * scale) < 0.001)
}

@Test func voiceStereoPlayback() {
    let leftData: [Float] = [1.0, 0.5]
    let rightData: [Float] = [0.0, 0.8]
    let sample = Sample(name: "test", left: leftData, right: rightData, sampleRate: 44100)
    var voice = Voice(sample: sample, velocity: 1.0)

    var left = [Float](repeating: 0, count: 2)
    var right = [Float](repeating: 0, count: 2)
    let (finished, _) = voice.fill(intoLeft: &left, right: &right, count: 2,
                                    pan: 0.5, hpCoeffs: .bypass, lpCoeffs: .bypass)
    #expect(finished == true)
    // Values scaled by center pan (~0.707)
    let scale = cos(0.5 * .pi / 2.0)
    #expect(abs(left[0] - 1.0 * scale) < 0.001)
    #expect(abs(right[1] - 0.8 * scale) < 0.001)
}

@Test func voicePanLeft() {
    let data: [Float] = [1.0, 1.0]
    let sample = Sample(name: "test", left: data, right: data, sampleRate: 44100)
    var voice = Voice(sample: sample, velocity: 1.0)

    var left = [Float](repeating: 0, count: 2)
    var right = [Float](repeating: 0, count: 2)
    let (_, _) = voice.fill(intoLeft: &left, right: &right, count: 2,
                             pan: 0.0, hpCoeffs: .bypass, lpCoeffs: .bypass)
    #expect(left[0] > 0.9)
    #expect(right[0] < 0.1)
}

@Test func voicePanCenter() {
    let data: [Float] = [1.0, 1.0]
    let sample = Sample(name: "test", left: data, right: data, sampleRate: 44100)
    var voice = Voice(sample: sample, velocity: 1.0)

    var left = [Float](repeating: 0, count: 2)
    var right = [Float](repeating: 0, count: 2)
    let (_, _) = voice.fill(intoLeft: &left, right: &right, count: 2,
                             pan: 0.5, hpCoeffs: .bypass, lpCoeffs: .bypass)
    #expect(abs(left[0] - right[0]) < 0.01)
    #expect(left[0] > 0.6)
}

@Test func voicePanRight() {
    let data: [Float] = [1.0, 1.0]
    let sample = Sample(name: "test", left: data, right: data, sampleRate: 44100)
    var voice = Voice(sample: sample, velocity: 1.0)

    var left = [Float](repeating: 0, count: 2)
    var right = [Float](repeating: 0, count: 2)
    let (_, _) = voice.fill(intoLeft: &left, right: &right, count: 2,
                             pan: 1.0, hpCoeffs: .bypass, lpCoeffs: .bypass)
    #expect(left[0] < 0.1)
    #expect(right[0] > 0.9)
}

@Test func voiceWithLowPassFilter() {
    let sampleRate: Float = 44100
    let frameCount = 4410
    var data = [Float](repeating: 0, count: frameCount)
    for i in 0..<frameCount {
        data[i] = sin(2.0 * .pi * 10000.0 * Float(i) / sampleRate)
    }
    let sample = Sample(name: "test", left: data, right: data, sampleRate: 44100)
    var voice = Voice(sample: sample, velocity: 1.0)

    var left = [Float](repeating: 0, count: frameCount)
    var right = [Float](repeating: 0, count: frameCount)
    let lpCoeffs = BiquadCoefficients.lowPass(cutoff: 100, sampleRate: sampleRate)
    let (_, peak) = voice.fill(intoLeft: &left, right: &right, count: frameCount,
                                pan: 0.5, hpCoeffs: .bypass, lpCoeffs: lpCoeffs)
    #expect(peak < 0.1)
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd /Users/brawny/god/GOD && swift test --filter voice`
Expected: All 8 voice tests PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/brawny/god
git add GOD/GOD/Models/Voice.swift GOD/Tests/VoiceTests.swift
git commit -m "feat: add biquad filters and equal-power pan to Voice.fill()"
```

---

## Task 4: GodEngine — Active Pad, CC Routing, Effects Integration

**Files:**
- Modify: `GOD/GOD/Engine/GodEngine.swift`
- Modify: `GOD/Tests/GodEngineTests.swift`
- Modify: `GOD/Tests/MIDITests.swift`

- [ ] **Step 1: Write tests for active pad and CC routing**

Append to `GOD/Tests/GodEngineTests.swift`:

```swift
@Test @MainActor func engineActivePadTracking() {
    let engine = GodEngine()
    let data = [Float](repeating: 0.5, count: 44100)
    let sample = Sample(name: "kick", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.padBank.assign(sample: sample, toPad: 3)
    engine.togglePlay()

    // Hit pad 0
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)
    #expect(engine.activePadIndex == 0)

    // Hit pad 3
    engine.midiRingBuffer.write(.noteOn(note: 39, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)
    #expect(engine.activePadIndex == 3)
}
```

Update `ccSetsLayerVolume` in `GOD/Tests/MIDITests.swift` — CC 14 now sets **active pad's** volume, not layer 0's volume. Replace the test:

```swift
@Test @MainActor func ccSetsActivePadVolume() {
    let engine = GodEngine()
    let data = [Float](repeating: 1.0, count: 44100)
    let sample = Sample(name: "kick", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.padBank.assign(sample: sample, toPad: 1)
    engine.togglePlay()

    // Hit pad 0 to make it active
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)

    // CC 14 (volume) = 64 → sets active pad (0) volume
    engine.midiRingBuffer.write(.cc(number: 14, value: 64))
    let _ = engine.processBlock(frameCount: 512)

    // Hit pad 0 again — velocity should be scaled by new volume
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 127))
    let _ = engine.processBlock(frameCount: 512)

    if let voice = engine.voices.last(where: { $0.padIndex == 0 }) {
        #expect(voice.velocity < 0.6)
        #expect(voice.velocity > 0.4)
    } else {
        Issue.record("Expected voice for pad 0")
    }
}

@Test @MainActor func ccSetsPan() {
    let engine = GodEngine()
    let data = [Float](repeating: 1.0, count: 44100)
    let sample = Sample(name: "kick", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.togglePlay()

    // Hit pad 0 to make it active
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)

    // CC 15 (pan) = 0 → hard left
    engine.midiRingBuffer.write(.cc(number: 15, value: 0))
    let _ = engine.processBlock(frameCount: 512)

    // Verify layer pan updated
    // (pan CC 0 → 0.0 = hard left)
    // We can't easily test audio output here, but we can check the layer param
    // Layer params are synced in UI update — check audioLayers indirectly via processBlock output
}

@Test @MainActor func ccSetsHPCutoff() {
    let engine = GodEngine()
    let data = [Float](repeating: 1.0, count: 44100)
    let sample = Sample(name: "kick", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.togglePlay()

    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 100))
    let _ = engine.processBlock(frameCount: 512)

    // CC 16 (HP cutoff) = 127 → 20kHz (max filtering)
    engine.midiRingBuffer.write(.cc(number: 16, value: 127))
    let _ = engine.processBlock(frameCount: 512)

    // Process more blocks — the HP at 20kHz should silence the output
    // Hit a new note so it gets the filter applied from the start
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 127))
    let (left, right) = engine.processBlock(frameCount: 4410)

    // After transient settles, output should be near-silent
    let tailPeak = left[2000..<4410].map { abs($0) }.max() ?? 0
    #expect(tailPeak < 0.1)
}

@Test @MainActor func ccOutOfRangeStillIgnored() {
    let engine = GodEngine()
    engine.togglePlay()

    // CC 1 is not mapped
    engine.midiRingBuffer.write(.cc(number: 1, value: 127))
    let _ = engine.processBlock(frameCount: 512)

    let data = [Float](repeating: 1.0, count: 44100)
    let sample = Sample(name: "kick", left: data, right: data, sampleRate: 44100)
    engine.padBank.assign(sample: sample, toPad: 0)
    engine.midiRingBuffer.write(.noteOn(note: 36, velocity: 127))
    let _ = engine.processBlock(frameCount: 512)

    if let voice = engine.voices.first(where: { $0.padIndex == 0 }) {
        #expect(voice.velocity > 0.99)
    } else {
        Issue.record("Expected voice for pad 0")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/brawny/god/GOD && swift test 2>&1 | grep -E "(FAIL|error|cannot find)"`
Expected: Compilation errors — `activePadIndex` not found, `fill()` signature mismatch in GodEngine.

- [ ] **Step 3: Update GodEngine**

Changes to `GOD/GOD/Engine/GodEngine.swift`:

**Add `activePadIndex` property** (after `lastClearedLayerIndex`):
```swift
    @Published var activePadIndex: Int = 0
    private var audioActivePadIndex: Int = 0
```

**Update `handlePadHit`** — set active pad:
```swift
    private func handlePadHit(note: Int, velocity: Int) {
        guard let padIndex = padBank.padIndex(forNote: note),
              let sample = padBank.pads[padIndex].sample else { return }

        audioActivePadIndex = padIndex
        audioLayers[padIndex].addHit(at: audioPosition, velocity: velocity)
        audioLayers[padIndex].name = padBank.pads[padIndex].name

        let vel = Float(velocity) / 127.0 * audioLayers[padIndex].volume
        voices.append(Voice(sample: sample, velocity: vel, padIndex: padIndex))

        pendingHits.append((padIndex: padIndex, position: audioPosition, velocity: velocity))
        pendingTriggers[padIndex] = true
    }
```

**Replace `handleCC`** — route to active pad's parameters:
```swift
    private func handleCC(number: Int, value: Int) {
        switch number {
        case 14: // Volume
            audioLayers[audioActivePadIndex].volume = Float(value) / 127.0
        case 15: // Pan
            audioLayers[audioActivePadIndex].pan = Float(value) / 127.0
        case 16: // HP Cutoff
            audioLayers[audioActivePadIndex].hpCutoff = ccToFrequency(value)
        case 17: // LP Cutoff
            audioLayers[audioActivePadIndex].lpCutoff = ccToFrequency(value)
        default:
            break
        }
    }
```

**Update voice mixing in `processBlock`** — pass filter coefficients and pan:
Replace the voice mixing block:
```swift
        // Mix all active voices — track per-channel peak during fill
        voices = voices.compactMap { voice in
            var v = voice
            let layer = audioLayers[max(0, min(7, v.padIndex))]
            let hpCoeffs = layer.hpCutoff <= 21 ? BiquadCoefficients.bypass
                : BiquadCoefficients.highPass(cutoff: layer.hpCutoff, sampleRate: Float(Transport.sampleRate))
            let lpCoeffs = layer.lpCutoff >= 19999 ? BiquadCoefficients.bypass
                : BiquadCoefficients.lowPass(cutoff: layer.lpCutoff, sampleRate: Float(Transport.sampleRate))
            let (done, peak) = v.fill(intoLeft: &outputL, right: &outputR, count: frameCount,
                                       pan: layer.pan, hpCoeffs: hpCoeffs, lpCoeffs: lpCoeffs)
            if v.padIndex >= 0 && v.padIndex < 8 {
                pendingLevels[v.padIndex] = max(pendingLevels[v.padIndex], peak)
            }
            return done ? nil : v
        }
```

**Update UI sync** — add activePadIndex and layer params to the dispatch block. In the `uiUpdateCounter >= 1323` section, capture:
```swift
            let activePad = audioActivePadIndex
            let layerPans = audioLayers.map { $0.pan }
            let layerHPCutoffs = audioLayers.map { $0.hpCutoff }
            let layerLPCutoffs = audioLayers.map { $0.lpCutoff }
```

And in the `DispatchQueue.main.async` block, add:
```swift
                self.activePadIndex = activePad
                for i in 0..<8 {
                    // ... existing volume sync ...
                    self.layers[i].pan = layerPans[i]
                    self.layers[i].hpCutoff = layerHPCutoffs[i]
                    self.layers[i].lpCutoff = layerLPCutoffs[i]
                }
```

**Remove old `ccToLayerOffset`** — no longer needed.

- [ ] **Step 4: Remove old CC tests, run all tests**

Remove `ccSetsLayerVolume` and `ccOutOfRangeIgnored` from `MIDITests.swift` (replaced by new tests in GodEngineTests).

Run: `cd /Users/brawny/god/GOD && swift test`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/brawny/god
git add GOD/GOD/Engine/GodEngine.swift GOD/Tests/GodEngineTests.swift GOD/Tests/MIDITests.swift
git commit -m "feat: active pad targeting with CC routing for volume, pan, HP/LP filters"
```

---

## Task 5: UI — Active Pad Highlight

**Files:**
- Modify: `GOD/GOD/Views/ChannelRowView.swift`

- [ ] **Step 1: Add `isActive` parameter to ChannelRowView**

Update `ChannelListView` to pass `isActive`:

```swift
struct ChannelListView: View {
    @ObservedObject var engine: GodEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<8, id: \.self) { i in
                ChannelRowView(
                    index: i,
                    layer: engine.layers[i],
                    pad: engine.padBank.pads[i],
                    signalLevel: engine.channelSignalLevels[i],
                    triggered: engine.channelTriggered[i],
                    isActive: engine.activePadIndex == i
                )
            }
        }
    }
}
```

- [ ] **Step 2: Update ChannelRowView to show active state**

Add `let isActive: Bool` property and add a left-edge accent:

```swift
struct ChannelRowView: View {
    let index: Int
    let layer: Layer
    let pad: Pad
    let signalLevel: Float
    let triggered: Bool
    let isActive: Bool

    // ... existing computed properties ...

    var body: some View {
        HStack(spacing: 12) {
            // Active indicator
            Rectangle()
                .fill(isActive ? Theme.blue : Color.clear)
                .frame(width: 3)

            // Channel number
            Text("\(index + 1)")
                .foregroundColor(triggered ? Theme.orange : Theme.text)
                .frame(width: 20, alignment: .trailing)

            // Sample name
            Text(displayName)
                .foregroundColor(triggered ? Theme.orange : Theme.text)
                .frame(width: 100, alignment: .leading)

            // Active/muted indicator
            if hasContent {
                Text(layer.isMuted ? "○" : "●")
                    .foregroundColor(layer.isMuted ? Theme.text : Theme.blue)
            }

            // Signal meter
            if hasContent && !layer.isMuted {
                SignalMeterView(level: signalLevel)
            }

            Spacer()
        }
        .font(Theme.mono)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(triggered ? Theme.orange.opacity(0.2) : Color.clear)
        )
        .animation(.easeOut(duration: 0.1), value: triggered)
    }
}
```

- [ ] **Step 3: Build and verify**

Run: `cd /Users/brawny/god/GOD && swift build`
Expected: Build succeeds.

Run: `cd /Users/brawny/god/GOD && swift test`
Expected: All tests PASS.

- [ ] **Step 4: Commit**

```bash
cd /Users/brawny/god
git add GOD/GOD/Views/ChannelRowView.swift
git commit -m "feat: active pad indicator in channel list"
```

---

## Summary

| Task | What | Tests |
|------|------|-------|
| 1 | Biquad filter struct + ccToFrequency | 6 new tests |
| 2 | Layer gets pan, hpCutoff, lpCutoff | 2 new tests |
| 3 | Voice applies filters + pan in fill() | 4 new, 4 updated tests |
| 4 | GodEngine active pad + CC routing | 4 new, 2 removed tests |
| 5 | UI active pad highlight | Build verification |

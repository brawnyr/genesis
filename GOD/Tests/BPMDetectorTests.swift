import Testing
@testable import GOD

@Test func bpmDetectorReturnsNilForShortSample() {
    // 0.2s at 44100 = 8820 frames, below 0.5s threshold
    let buffer = [Float](repeating: 0.0, count: 8820)
    let result = BPMDetector.detect(buffer: buffer, sampleRate: 44100)
    #expect(result == nil)
}

@Test func bpmDetectorReturnsBPMForRhythmicSignal() {
    // Generate a click track at 120 BPM (0.5s per beat) for 4 seconds
    let sampleRate = 44100.0
    let bpm = 120.0
    let duration = 4.0
    let samplesPerBeat = Int(60.0 / bpm * sampleRate)
    let totalSamples = Int(duration * sampleRate)
    var buffer = [Float](repeating: 0.0, count: totalSamples)

    // Place sharp transients at each beat
    for beat in 0..<Int(duration * bpm / 60.0) {
        let pos = beat * samplesPerBeat
        if pos < totalSamples {
            for i in 0..<min(200, totalSamples - pos) {
                buffer[pos + i] = Float.random(in: 0.5...1.0) * (1.0 - Float(i) / 200.0)
            }
        }
    }

    let result = BPMDetector.detect(buffer: buffer, sampleRate: sampleRate)
    #expect(result != nil)
    if let detected = result {
        // Should be within 10% of 120 BPM
        #expect(detected > 108 && detected < 132)
    }
}

@Test func bpmDetectorClampsToRange() {
    // Very fast clicks at 300 BPM should be halved into 70-180 range
    let sampleRate = 44100.0
    let bpm = 300.0
    let duration = 4.0
    let samplesPerBeat = Int(60.0 / bpm * sampleRate)
    let totalSamples = Int(duration * sampleRate)
    var buffer = [Float](repeating: 0.0, count: totalSamples)

    for beat in 0..<Int(duration * bpm / 60.0) {
        let pos = beat * samplesPerBeat
        if pos < totalSamples {
            for i in 0..<min(100, totalSamples - pos) {
                buffer[pos + i] = Float.random(in: 0.5...1.0)
            }
        }
    }

    let result = BPMDetector.detect(buffer: buffer, sampleRate: sampleRate)
    if let detected = result {
        #expect(detected >= 70 && detected <= 180)
    }
}

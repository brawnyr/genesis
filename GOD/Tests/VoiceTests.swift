import Foundation
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
    let scale: Float = cos(0.5 * .pi / 2.0)
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
    let scale: Float = cos(0.5 * .pi / 2.0)
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
    let scale: Float = cos(0.5 * .pi / 2.0)
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

import Testing
@testable import GOD

@Test func voicePlayback() {
    let data: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
    let sample = Sample(name: "test", data: data, sampleRate: 44100)
    var voice = Voice(sample: sample, velocity: 1.0)

    var buffer = [Float](repeating: 0, count: 3)
    let finished = voice.fill(into: &buffer, count: 3)
    #expect(finished == false)
    #expect(buffer[0] == 0.1)
    #expect(buffer[1] == 0.2)
    #expect(buffer[2] == 0.3)
}

@Test func voiceFinishes() {
    let data: [Float] = [0.1, 0.2]
    let sample = Sample(name: "test", data: data, sampleRate: 44100)
    var voice = Voice(sample: sample, velocity: 1.0)

    var buffer = [Float](repeating: 0, count: 4)
    let finished = voice.fill(into: &buffer, count: 4)
    #expect(finished == true)
    #expect(buffer[0] == 0.1)
    #expect(buffer[1] == 0.2)
    #expect(buffer[2] == 0)
    #expect(buffer[3] == 0)
}

@Test func voiceVelocityScaling() {
    let data: [Float] = [1.0, 1.0]
    let sample = Sample(name: "test", data: data, sampleRate: 44100)
    var voice = Voice(sample: sample, velocity: 0.5)

    var buffer = [Float](repeating: 0, count: 2)
    _ = voice.fill(into: &buffer, count: 2)
    #expect(buffer[0] == 0.5)
}

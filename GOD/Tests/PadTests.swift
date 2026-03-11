import Testing
import Foundation
@testable import GOD

@Test func padMIDINoteMapping() {
    let pads = PadBank()
    #expect(pads.padIndex(forNote: 36) == 0)
    #expect(pads.padIndex(forNote: 43) == 7)
    #expect(pads.padIndex(forNote: 44) == nil)
    #expect(pads.padIndex(forNote: 35) == nil)
}

@Test func padSampleAssignment() {
    var pads = PadBank()
    let sample = Sample(name: "kick", left: [0.1, 0.2], right: [0.1, 0.2], sampleRate: 44100)
    pads.assign(sample: sample, toPad: 0)
    #expect(pads.pads[0].sample?.name == "kick")
}

@Test func padConfigSerialization() {
    var pads = PadBank()
    pads.pads[0].samplePath = "/path/to/kick.wav"
    pads.pads[0].name = "KICK"
    let data = try! JSONEncoder().encode(pads.config)
    let decoded = try! JSONDecoder().decode(PadConfig.self, from: data)
    #expect(decoded.assignments["0"]?.path == "/path/to/kick.wav")
}

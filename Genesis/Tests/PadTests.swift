import Testing
import Foundation
@testable import Genesis

@Test func padMIDINoteMapping() {
    let pads = PadBank()
    #expect(pads.padIndex(forNote: 36) == 0)
    #expect(pads.padIndex(forNote: 43) == 7)
    #expect(pads.padIndex(forNote: 44) == nil)
    #expect(pads.padIndex(forNote: 35) == nil)
}

@Test func padConfigSerialization() {
    var pads = PadBank()
    pads.pads[0].samplePath = "/path/to/kick.wav"
    pads.pads[0].name = "KICK"
    let data = try! JSONEncoder().encode(pads.config)
    let decoded = try! JSONDecoder().decode(PadConfig.self, from: data)
    #expect(decoded.assignments["0"]?.path == "/path/to/kick.wav")
}

@Test func padChokeBackwardsCompat() {
    let json = """
    {"assignments":{"0":{"path":"/kick.wav","name":"KICK"}}}
    """
    let data = json.data(using: .utf8)!
    let decoded = try! JSONDecoder().decode(PadConfig.self, from: data)
    #expect(decoded.assignments["0"]?.choke == nil)
}

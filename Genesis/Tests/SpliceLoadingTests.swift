import Testing
@testable import Genesis

@Test func loadFromSpliceSkipsLoadedPads() {
    var bank = PadBank()
    let sample = Sample(name: "manual", left: [0.1], right: [0.1], sampleRate: 44100)
    bank.assign(sample: sample, toPad: 0)
    bank.pads[0].samplePath = "/manual/kick.wav"

    // After loading splice, pad 0 should still have the manual sample
    bank.loadFromSpliceFolders()
    #expect(bank.pads[0].sample?.name == "manual")
    #expect(bank.pads[0].samplePath == "/manual/kick.wav")
}

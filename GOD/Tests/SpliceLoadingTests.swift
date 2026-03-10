import Testing
@testable import GOD

@Test func sampleDurationMs() {
    // 44100 frames at 44100Hz = 1000ms
    let sample = Sample(name: "test", left: [Float](repeating: 0, count: 44100),
                        right: [Float](repeating: 0, count: 44100), sampleRate: 44100)
    #expect(sample.durationMs == 1000.0)
}

@Test func sampleDurationMsShort() {
    // 22050 frames at 44100Hz = 500ms
    let sample = Sample(name: "short", left: [Float](repeating: 0, count: 22050),
                        right: [Float](repeating: 0, count: 22050), sampleRate: 44100)
    #expect(sample.durationMs == 500.0)
}

@Test func spliceFolderNames() {
    #expect(PadBank.spliceFolderNames == ["kicks", "snares", "hats", "perc", "bass", "keys", "vox", "fx"])
}

@Test func spliceFolderPath() {
    let base = PadBank.spliceBasePath
    #expect(base.path.hasSuffix("Splice/sounds"))
}

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

import Testing
@testable import Genesis

@Test func bpmExtractsFromFilename() {
    #expect(BPMDetector.extractFromName("kick_120_C") == 120)
    #expect(BPMDetector.extractFromName("140bpm_snare") == 140)
    #expect(BPMDetector.extractFromName("snare_bpm95") == 95)
    #expect(BPMDetector.extractFromName("85_lofi_hat") == 85)
    #expect(BPMDetector.extractFromName("ambient_pad") == nil)
    #expect(BPMDetector.extractFromName("hit_01") == nil)
}

@Test func bpmRejectsOutOfRange() {
    #expect(BPMDetector.extractFromName("kick_30_low") == nil)
    #expect(BPMDetector.extractFromName("250bpm_fast") == nil)
}

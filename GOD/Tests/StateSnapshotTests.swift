import Testing
import Foundation
@testable import GOD

@Test func snapshotChannelTruncation() {
    // Sample is 10000ms, loop is 8000ms — should be truncated
    let channel = StateSnapshot.Channel(
        ch: 1, sample: "pad.wav",
        sampleDurationMs: 10000, loopDurationMs: 8000,
        hits: 1, muted: false,
        volume: 1.0, pan: 0.5,
        hpHz: 20, lpHz: 20000,
        peakDb: -12.0
    )
    #expect(channel.truncated == true)
}

@Test func snapshotChannelNotTruncated() {
    let channel = StateSnapshot.Channel(
        ch: 1, sample: "kick.wav",
        sampleDurationMs: 450, loopDurationMs: 8000,
        hits: 4, muted: false,
        volume: 0.8, pan: 0.5,
        hpHz: 20, lpHz: 20000,
        peakDb: -6.0
    )
    #expect(channel.truncated == false)
}

@Test func snapshotEncodesToJSON() throws {
    let snapshot = StateSnapshot(
        bpm: 120, bars: 4, beat: 1,
        playing: true, capture: "idle",
        channels: [
            StateSnapshot.Channel(
                ch: 1, sample: "kick.wav",
                sampleDurationMs: 450, loopDurationMs: 8000,
                hits: 4, muted: false,
                volume: 0.8, pan: 0.5,
                hpHz: 20, lpHz: 20000,
                peakDb: -12.0
            )
        ]
    )
    let data = try JSONEncoder().encode(snapshot)
    let json = String(data: data, encoding: .utf8)!
    #expect(json.contains("\"bpm\":120"))
    #expect(json.contains("\"truncated\":false"))
}

@Test func engineProducesSnapshot() {
    let engine = GodEngine()
    let snapshot = engine.stateSnapshot(peakLevels: Array(repeating: Float(-20.0), count: 8))
    #expect(snapshot.bpm == 120)
    #expect(snapshot.bars == 4)
    #expect(snapshot.playing == false)
    #expect(snapshot.channels.count == 8)
}

import Foundation

struct StateSnapshot: Codable {
    let bpm: Int
    let bars: Int
    let beat: Int
    let playing: Bool
    let capture: String
    let channels: [Channel]

    struct Channel: Codable {
        let ch: Int
        let sample: String
        let sampleDurationMs: Double
        let loopDurationMs: Double
        let hits: Int
        let muted: Bool
        let volume: Float
        let pan: Float
        let hpHz: Float
        let lpHz: Float
        let peakDb: Float
        var truncated: Bool { sampleDurationMs > loopDurationMs }

        init(
            ch: Int, sample: String,
            sampleDurationMs: Double, loopDurationMs: Double,
            hits: Int, muted: Bool,
            volume: Float, pan: Float,
            hpHz: Float, lpHz: Float,
            peakDb: Float
        ) {
            self.ch = ch
            self.sample = sample
            self.sampleDurationMs = sampleDurationMs
            self.loopDurationMs = loopDurationMs
            self.hits = hits
            self.muted = muted
            self.volume = volume
            self.pan = pan
            self.hpHz = hpHz
            self.lpHz = lpHz
            self.peakDb = peakDb
        }

        enum CodingKeys: String, CodingKey {
            case ch, sample
            case sampleDurationMs = "sample_duration_ms"
            case loopDurationMs = "loop_duration_ms"
            case hits, muted, volume, pan
            case hpHz = "hp_hz"
            case lpHz = "lp_hz"
            case peakDb = "peak_db"
            case truncated
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            ch = try container.decode(Int.self, forKey: .ch)
            sample = try container.decode(String.self, forKey: .sample)
            sampleDurationMs = try container.decode(Double.self, forKey: .sampleDurationMs)
            loopDurationMs = try container.decode(Double.self, forKey: .loopDurationMs)
            hits = try container.decode(Int.self, forKey: .hits)
            muted = try container.decode(Bool.self, forKey: .muted)
            volume = try container.decode(Float.self, forKey: .volume)
            pan = try container.decode(Float.self, forKey: .pan)
            hpHz = try container.decode(Float.self, forKey: .hpHz)
            lpHz = try container.decode(Float.self, forKey: .lpHz)
            peakDb = try container.decode(Float.self, forKey: .peakDb)
            // truncated is computed from sampleDurationMs and loopDurationMs; ignore encoded value
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(ch, forKey: .ch)
            try container.encode(sample, forKey: .sample)
            try container.encode(sampleDurationMs, forKey: .sampleDurationMs)
            try container.encode(loopDurationMs, forKey: .loopDurationMs)
            try container.encode(hits, forKey: .hits)
            try container.encode(muted, forKey: .muted)
            try container.encode(volume, forKey: .volume)
            try container.encode(pan, forKey: .pan)
            try container.encode(hpHz, forKey: .hpHz)
            try container.encode(lpHz, forKey: .lpHz)
            try container.encode(peakDb, forKey: .peakDb)
            try container.encode(truncated, forKey: .truncated)
        }
    }
}

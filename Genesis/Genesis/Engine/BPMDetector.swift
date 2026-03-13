import Foundation

enum BPMDetector {
    /// Pre-compiled regex patterns for BPM extraction
    private static let patterns: [NSRegularExpression] = {
        let raw = [
            #"(\d{2,3})\s*bpm"#,       // "120bpm", "120 bpm"
            #"bpm\s*(\d{2,3})"#,        // "bpm120", "bpm 120"
            #"[_\-\s](\d{2,3})[_\-\s]"#, // "_140_", "-140-", " 140 "
            #"^(\d{2,3})[_\-\s]"#,      // "120_kick", "140-snare"
        ]
        return raw.compactMap { try? NSRegularExpression(pattern: $0, options: []) }
    }()

    /// Extract BPM from a filename. Matches patterns like "120_bpm", "bpm120", "120bpm", "_140_", etc.
    static func extractFromName(_ name: String) -> Double? {
        let lower = name.lowercased()
        let range = NSRange(lower.startIndex..., in: lower)
        for regex in patterns {
            if let match = regex.firstMatch(in: lower, range: range) {
                let captureRange = match.range(at: 1)
                if let swiftRange = Range(captureRange, in: lower),
                   let bpm = Double(lower[swiftRange]),
                   bpm >= 60, bpm <= 200 {
                    return bpm
                }
            }
        }
        return nil
    }
}

import Foundation

enum BPMDetector {
    /// Extract BPM from a filename. Matches patterns like "120_bpm", "bpm120", "120bpm", "_140_", etc.
    static func extractFromName(_ name: String) -> Double? {
        let patterns = [
            #"(\d{2,3})\s*bpm"#,       // "120bpm", "120 bpm"
            #"bpm\s*(\d{2,3})"#,        // "bpm120", "bpm 120"
            #"[_\-\s](\d{2,3})[_\-\s]"#, // "_140_", "-140-", " 140 "
            #"^(\d{2,3})[_\-\s]"#,      // "120_kick", "140-snare"
        ]
        let lower = name.lowercased()
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let range = NSRange(lower.startIndex..., in: lower)
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

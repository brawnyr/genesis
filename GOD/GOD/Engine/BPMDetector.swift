import Foundation
import Accelerate

enum BPMDetector {
    /// Minimum sample duration for BPM detection (0.5 seconds)
    private static let minFrames = 22050

    // Detection parameters
    private static let windowSize = 1024
    private static let hopSize = 512
    private static let onsetThresholdMultiplier: Float = 1.5
    private static let minIntervalSec: Double = 0.15
    private static let maxIntervalSec: Double = 2.0
    private static let histogramBinSec: Double = 0.02
    private static let maxBPM: Double = 180
    private static let minBPM: Double = 70

    /// Detect BPM from a mono audio buffer using energy-based onset detection.
    /// Returns nil if the sample is too short or detection fails.
    static func detect(buffer: [Float], sampleRate: Double) -> Double? {
        guard buffer.count >= minFrames else { return nil }

        // 1. Compute short-time energy in windows
        let windowSize = self.windowSize
        let hopSize = self.hopSize
        let windowCount = (buffer.count - windowSize) / hopSize
        guard windowCount > 4 else { return nil }

        var energies = [Float](repeating: 0, count: windowCount)
        for i in 0..<windowCount {
            let start = i * hopSize
            let slice = Array(buffer[start..<start + windowSize])
            var sumSq: Float = 0
            vDSP_svesq(slice, 1, &sumSq, vDSP_Length(windowSize))
            energies[i] = sumSq
        }

        // 2. Compute onset detection function (first-order difference of energy)
        var onsetFunc = [Float](repeating: 0, count: windowCount - 1)
        for i in 0..<windowCount - 1 {
            onsetFunc[i] = max(0, energies[i + 1] - energies[i])
        }

        // 3. Find peaks in onset function (local maxima above mean)
        var mean: Float = 0
        vDSP_meanv(onsetFunc, 1, &mean, vDSP_Length(onsetFunc.count))
        let threshold = mean * onsetThresholdMultiplier

        var onsetPositions: [Int] = []
        for i in 1..<onsetFunc.count - 1 {
            if onsetFunc[i] > threshold &&
               onsetFunc[i] > onsetFunc[i - 1] &&
               onsetFunc[i] >= onsetFunc[i + 1] {
                onsetPositions.append(i)
            }
        }

        guard onsetPositions.count >= 2 else { return nil }

        // 4. Compute inter-onset intervals in seconds
        let hopDuration = Double(hopSize) / sampleRate
        var intervals: [Double] = []
        for i in 1..<onsetPositions.count {
            let interval = Double(onsetPositions[i] - onsetPositions[i - 1]) * hopDuration
            if interval > minIntervalSec && interval < maxIntervalSec {
                intervals.append(interval)
            }
        }

        guard !intervals.isEmpty else { return nil }

        // 5. Find most common interval via histogram
        let binSize = histogramBinSec
        var histogram: [Int: Int] = [:]
        for interval in intervals {
            let bin = Int(interval / binSize)
            histogram[bin, default: 0] += 1
        }

        guard let bestBin = histogram.max(by: { $0.value < $1.value }) else { return nil }
        let bestInterval = (Double(bestBin.key) + 0.5) * binSize
        var bpm = 60.0 / bestInterval

        // 6. Normalize to 70-180 BPM range
        while bpm > maxBPM { bpm /= 2 }
        while bpm < minBPM { bpm *= 2 }

        return bpm
    }
}

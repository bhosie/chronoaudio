import AVFoundation
import Accelerate

/// Estimates the tempo (BPM) of an audio file using spectral-flux onset
/// detection followed by inter-onset-interval (IOI) histogram analysis.
///
/// Algorithm:
///   1. Compute spectral flux curve from the PCM buffer (via OnsetDetector).
///   2. Pick onset peaks: a frame is a peak if it exceeds a local adaptive threshold.
///   3. Build a histogram of inter-onset intervals (IOIs) in the range 60–200 BPM.
///   4. Return the BPM corresponding to the most common IOI, also checking its
///      octave doubles/halves so we don't accidentally return half- or double-time.
final class BeatDetector {

    private let onsetDetector: OnsetDetector
    private let hopSize: Int
    private let sampleRate: Double

    /// - Parameters:
    ///   - fftSize: FFT window size (power of 2). Larger = more freq resolution.
    ///   - hopSize: Frame hop in samples. Smaller = finer time resolution.
    ///   - sampleRate: Expected sample rate of buffers passed to `detect(from:)`.
    init(fftSize: Int = 2048, hopSize: Int = 512, sampleRate: Double = 44100) {
        self.onsetDetector = OnsetDetector(fftSize: fftSize)
        self.hopSize = hopSize
        self.sampleRate = sampleRate
    }

    // MARK: - Public API

    /// Detect tempo from a PCM buffer. Runs on the calling thread (use a background task).
    /// Returns nil if the buffer is too short or no clear tempo is found.
    func detect(from buffer: AVAudioPCMBuffer) async -> Double? {
        guard buffer.frameLength > UInt32(hopSize * 4) else { return nil }

        // 1. Spectral flux curve
        let flux = onsetDetector.spectralFlux(from: buffer, hopSize: hopSize)
        guard flux.count > 8 else { return nil }

        // 2. Peak-pick onsets using adaptive local threshold
        let onsetFrames = pickPeaks(flux: flux)
        guard onsetFrames.count >= 4 else { return nil }

        // 3. Convert frame indices → seconds
        let frameSeconds = onsetFrames.map { Double($0) * Double(hopSize) / sampleRate }

        // 4. Compute IOIs and build BPM histogram
        var iois: [Double] = []
        for i in 1 ..< frameSeconds.count {
            let ioi = frameSeconds[i] - frameSeconds[i - 1]
            if ioi > 0 { iois.append(ioi) }
        }
        guard !iois.isEmpty else { return nil }

        return bpmFromIOIs(iois)
    }

    // MARK: - Peak picking

    /// Adaptive threshold peak picker: a frame is an onset if it is a local maximum
    /// and exceeds (mean + multiplier * std) of a surrounding window.
    private func pickPeaks(flux: [Float], windowSize: Int = 16, multiplier: Float = 1.2) -> [Int] {
        var peaks: [Int] = []
        let n = flux.count

        for i in 1 ..< n - 1 {
            guard flux[i] > flux[i - 1], flux[i] > flux[i + 1] else { continue }

            // Local window around i
            let lo = max(0, i - windowSize / 2)
            let hi = min(n, i + windowSize / 2)
            let window = Array(flux[lo ..< hi])

            var mean: Float = 0
            vDSP_meanv(window, 1, &mean, vDSP_Length(window.count))

            var variance: Float = 0
            vDSP_measqv(window, 1, &variance, vDSP_Length(window.count))
            let std = sqrt(max(0, variance - mean * mean))

            let threshold = mean + multiplier * std
            if flux[i] > threshold {
                peaks.append(i)
            }
        }
        return peaks
    }

    // MARK: - IOI → BPM

    /// Build a histogram of candidate BPMs from inter-onset intervals,
    /// then return the strongest bin, checking octave consistency.
    private func bpmFromIOIs(_ iois: [Double]) -> Double? {
        // Only consider IOIs in the 60–200 BPM range
        let minIOI = 60.0 / 200.0   // 0.3 s
        let maxIOI = 60.0 / 60.0    // 1.0 s

        let binCount = 200
        let bpmLow: Double = 60
        let bpmHigh: Double = 200
        var histogram = [Int](repeating: 0, count: binCount)

        for ioi in iois {
            var candidates = [ioi]
            // Also consider multiples/fractions to capture metrical levels
            candidates.append(ioi * 2)
            candidates.append(ioi / 2)

            for candidate in candidates {
                guard candidate >= minIOI, candidate <= maxIOI else { continue }
                let bpm = 60.0 / candidate
                let bin = Int((bpm - bpmLow) / (bpmHigh - bpmLow) * Double(binCount))
                let clampedBin = max(0, min(binCount - 1, bin))
                histogram[clampedBin] += 1
            }
        }

        // Find the highest bin
        guard let maxCount = histogram.max(), maxCount > 0 else { return nil }
        guard let bestBin = histogram.firstIndex(of: maxCount) else { return nil }

        let rawBPM = bpmLow + (Double(bestBin) + 0.5) * (bpmHigh - bpmLow) / Double(binCount)

        // Round to nearest 0.5 BPM for a clean display value
        return (rawBPM * 2).rounded() / 2
    }
}

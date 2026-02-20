import Accelerate
import AVFoundation

/// Computes per-frame spectral flux from a sequence of magnitude spectra.
/// Spectral flux measures how much the spectrum changes frame-to-frame —
/// spikes correspond to note onsets (drum hits, picked notes, etc.).
final class OnsetDetector {

    private let fftSize: Int
    private let log2n: vDSP_Length
    private var fftSetup: FFTSetup

    init(fftSize: Int = 2048) {
        self.fftSize = fftSize
        self.log2n = vDSP_Length(log2(Double(fftSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    // MARK: - Public API

    /// Slice a mono PCM buffer into overlapping frames and return one spectral-flux
    /// value per frame. Frame values are normalised to [0, 1].
    func spectralFlux(from buffer: AVAudioPCMBuffer, hopSize: Int = 512) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }
        let samples = Array(UnsafeBufferPointer(start: channelData[0],
                                                count: Int(buffer.frameLength)))
        let frames = makeFrames(samples: samples, hopSize: hopSize)
        return computeSpectralFlux(frames: frames)
    }

    // MARK: - Internal

    /// Split samples into overlapping windows of `fftSize`, stepped by `hopSize`.
    private func makeFrames(samples: [Float], hopSize: Int) -> [[Float]] {
        var frames: [[Float]] = []
        var start = 0
        while start + fftSize <= samples.count {
            frames.append(Array(samples[start ..< start + fftSize]))
            start += hopSize
        }
        return frames
    }

    /// For each frame compute its magnitude spectrum, then return the
    /// half-wave-rectified difference between consecutive spectra (spectral flux).
    func computeSpectralFlux(frames: [[Float]]) -> [Float] {
        guard !frames.isEmpty else { return [] }

        var prevMag = [Float](repeating: 0, count: fftSize / 2)
        var fluxValues: [Float] = []
        fluxValues.reserveCapacity(frames.count)

        for frame in frames {
            let mag = magnitude(of: frame)
            // Half-wave rectify: only keep increases in energy (onsets, not offsets)
            var diff = [Float](repeating: 0, count: mag.count)
            for i in 0 ..< mag.count {
                diff[i] = max(0, mag[i] - prevMag[i])
            }
            var flux: Float = 0
            vDSP_sve(diff, 1, &flux, vDSP_Length(diff.count))
            fluxValues.append(flux)
            prevMag = mag
        }

        // Normalise to [0, 1]
        var maxVal: Float = 0
        vDSP_maxv(fluxValues, 1, &maxVal, vDSP_Length(fluxValues.count))
        if maxVal > 0 {
            var scale = 1.0 / maxVal
            vDSP_vsmul(fluxValues, 1, &scale, &fluxValues, 1, vDSP_Length(fluxValues.count))
        }
        return fluxValues
    }

    // MARK: - FFT helpers

    private func magnitude(of frame: [Float]) -> [Float] {
        let windowed = applyHannWindow(to: frame)

        // Pack real signal into split-complex form required by vDSP.
        // Use withUnsafeMutableBufferPointer so the pointers are valid for the
        // entire scope of the FFT calls (not just the duration of init).
        let halfN = fftSize / 2
        var realp = [Float](repeating: 0, count: halfN)
        var imagp = [Float](repeating: 0, count: halfN)
        var mag = [Float](repeating: 0, count: halfN)

        realp.withUnsafeMutableBufferPointer { realBuf in
            imagp.withUnsafeMutableBufferPointer { imagBuf in
                var splitComplex = DSPSplitComplex(realp: realBuf.baseAddress!,
                                                   imagp: imagBuf.baseAddress!)
                windowed.withUnsafeBytes { ptr in
                    let floatPtr = ptr.bindMemory(to: DSPComplex.self)
                    vDSP_ctoz(floatPtr.baseAddress!, 2, &splitComplex, 1, vDSP_Length(halfN))
                }
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                mag.withUnsafeMutableBufferPointer { magBuf in
                    var sc2 = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                    vDSP_zvmags(&sc2, 1, magBuf.baseAddress!, 1, vDSP_Length(halfN))
                }
            }
        }

        // Scale
        var scale: Float = 1.0 / Float(fftSize)
        vDSP_vsmul(mag, 1, &scale, &mag, 1, vDSP_Length(halfN))
        return mag
    }

    private func applyHannWindow(to frame: [Float]) -> [Float] {
        var window = [Float](repeating: 0, count: frame.count)
        vDSP_hann_window(&window, vDSP_Length(frame.count), Int32(vDSP_HANN_NORM))
        var result = [Float](repeating: 0, count: frame.count)
        vDSP_vmul(frame, 1, window, 1, &result, 1, vDSP_Length(frame.count))
        return result
    }
}

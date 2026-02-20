import AVFoundation
import Accelerate

final class WaveformSampler {
    /// Downsample an AVAudioPCMBuffer to `targetCount` RMS values in [0, 1].
    /// Runs on whatever async context the caller provides; never blocks the main thread.
    func sample(buffer: AVAudioPCMBuffer, targetCount: Int) async -> [Float] {
        guard targetCount > 0,
              let channelData = buffer.floatChannelData else {
            return []
        }

        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else {
            return Array(repeating: 0, count: targetCount)
        }

        let channelCount = Int(buffer.format.channelCount)
        guard channelCount > 0 else {
            return Array(repeating: 0, count: targetCount)
        }

        // Mix down to mono by averaging channels
        var mono = [Float](repeating: 0, count: frameCount)
        for ch in 0..<channelCount {
            let src = channelData[ch]
            vDSP_vadd(mono, 1, src, 1, &mono, 1, vDSP_Length(frameCount))
        }
        if channelCount > 1 {
            var divisor = Float(channelCount)
            vDSP_vsdiv(mono, 1, &divisor, &mono, 1, vDSP_Length(frameCount))
        }

        // Compute RMS for each window
        let windowSize = max(1, frameCount / targetCount)
        var result = [Float]()
        result.reserveCapacity(targetCount)

        for i in 0..<targetCount {
            let start = i * windowSize
            let end = min(start + windowSize, frameCount)
            let count = end - start
            if count <= 0 {
                result.append(0)
                continue
            }
            var rms: Float = 0
            vDSP_rmsqv(mono.withUnsafeBufferPointer { $0.baseAddress! + start }, 1, &rms, vDSP_Length(count))
            result.append(rms)
        }

        // Normalize to [0, 1]
        var maxVal: Float = 0
        vDSP_maxv(result, 1, &maxVal, vDSP_Length(result.count))

        if maxVal > 0 {
            var divisor = maxVal
            vDSP_vsdiv(result, 1, &divisor, &result, 1, vDSP_Length(result.count))
        }

        return result
    }
}

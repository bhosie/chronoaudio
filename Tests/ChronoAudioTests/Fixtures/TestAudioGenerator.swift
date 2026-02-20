import AVFoundation
import Foundation

enum TestAudioGenerator {

    /// Generates a mono 440 Hz sine wave AIFF file in a temp directory.
    /// Returns the URL of the generated file.
    static func generateSineWave(
        frequency: Double = 440,
        sampleRate: Double = 44100,
        durationSeconds: Double = 1.0
    ) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_sine_\(Int(frequency))hz.aiff")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false
        ]

        let audioFile = try AVAudioFile(forWriting: url, settings: settings)
        let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ), let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "TestAudioGenerator", code: 1)
        }

        buffer.frameLength = frameCount
        let channelData = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            channelData[i] = Float(sin(2.0 * Double.pi * frequency * t))
        }

        try audioFile.write(from: buffer)
        return url
    }

    /// Generates a click-track PCM buffer at the given BPM.
    static func generateClickTrackBuffer(
        bpm: Double = 120,
        sampleRate: Double = 44100,
        durationSeconds: Double = 4.0
    ) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ), let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount
        let channelData = buffer.floatChannelData![0]

        // Zero out
        for i in 0..<Int(frameCount) { channelData[i] = 0 }

        // Place impulses at BPM intervals
        let framesPerBeat = Int(sampleRate * 60.0 / bpm)
        var frame = 0
        while frame < Int(frameCount) {
            channelData[frame] = 1.0
            frame += framesPerBeat
        }

        return buffer
    }
}

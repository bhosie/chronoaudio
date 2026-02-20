import AVFoundation
import UniformTypeIdentifiers

final class AudioFileLoader {

    private let supportedTypes: [UTType] = [
        .mp3,
        .aiff,
        .wav,
        UTType("public.aac-audio") ?? .audio
    ]

    /// Fast path: reads metadata only, no PCM decode. Returns immediately.
    /// Call `loadPCMBuffer(for:)` on a background thread to fill in the waveform buffer.
    func load(url: URL) throws -> (track: AudioTrack, audioFile: AVAudioFile) {
        // Validate file type
        guard let fileType = UTType(filenameExtension: url.pathExtension),
              supportedTypes.contains(where: { fileType.conforms(to: $0) }) else {
            throw AudioFileError.unsupportedFormat
        }

        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.fileFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        let duration = Double(frameCount) / format.sampleRate

        // Return track with pcmBuffer = nil — waveform loads separately via loadPCMBuffer
        let track = AudioTrack(
            url: url,
            duration: duration,
            sampleRate: format.sampleRate,
            channelCount: Int(format.channelCount),
            frameCount: frameCount,
            pcmBuffer: nil
        )

        return (track, audioFile)
    }

    /// Slow path: decodes the full file into a Float32 PCM buffer for waveform display.
    /// Always call this on a background thread — it blocks while decoding.
    func loadPCMBuffer(for url: URL, frameCount: AVAudioFrameCount, sampleRate: Double, channelCount: AVAudioChannelCount) throws -> AVAudioPCMBuffer {
        guard let processingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        ) else {
            throw AudioFileError.formatConversionFailed
        }

        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: frameCount) else {
            throw AudioFileError.readFailed
        }

        let audioFileForBuffer = try AVAudioFile(forReading: url)
        try audioFileForBuffer.read(into: pcmBuffer)
        return pcmBuffer
    }
}

enum AudioFileError: LocalizedError {
    case unsupportedFormat
    case formatConversionFailed
    case readFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "Unsupported audio format. Use MP3, AAC, WAV, or AIFF."
        case .formatConversionFailed: return "Could not convert audio format for processing."
        case .readFailed: return "Failed to read audio file."
        }
    }
}

import AVFoundation
import UniformTypeIdentifiers

final class AudioFileLoader {

    private let supportedTypes: [UTType] = [
        .mp3,
        .aiff,
        .wav,
        UTType("public.aac-audio") ?? .audio
    ]

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

        // Read into PCM buffer for waveform display
        guard let processingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: format.sampleRate,
            channels: format.channelCount,
            interleaved: false
        ) else {
            throw AudioFileError.formatConversionFailed
        }

        let pcmBuffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: frameCount)
        // Re-open file for reading into PCM buffer (AVAudioFile cursor advances on read)
        let audioFileForBuffer = try AVAudioFile(forReading: url)
        try audioFileForBuffer.read(into: pcmBuffer!)

        let track = AudioTrack(
            url: url,
            duration: duration,
            sampleRate: format.sampleRate,
            channelCount: Int(format.channelCount),
            frameCount: frameCount,
            pcmBuffer: pcmBuffer
        )

        return (track, audioFile)
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

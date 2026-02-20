import AVFoundation

struct AudioTrack: Equatable {
    let url: URL
    let duration: TimeInterval
    let sampleRate: Double
    let channelCount: Int
    let frameCount: AVAudioFrameCount
    let pcmBuffer: AVAudioPCMBuffer?

    static func == (lhs: AudioTrack, rhs: AudioTrack) -> Bool {
        lhs.url == rhs.url
    }
}

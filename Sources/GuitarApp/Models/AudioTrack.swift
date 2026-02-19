import AVFoundation

struct AudioTrack {
    let url: URL
    let duration: TimeInterval
    let sampleRate: Double
    let channelCount: Int
    let frameCount: AVAudioFrameCount
    let pcmBuffer: AVAudioPCMBuffer?
}

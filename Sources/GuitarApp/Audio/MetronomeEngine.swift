import AVFoundation

final class MetronomeEngine {
    private let engine: AVAudioEngine
    private let playerNode = AVAudioPlayerNode()

    init(engine: AVAudioEngine) {
        self.engine = engine
    }
}

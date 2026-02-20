import AVFoundation

final class TimePitchController {
    private let node: AVAudioUnitTimePitch

    init(node: AVAudioUnitTimePitch) {
        self.node = node
    }

    /// Rate: 0.25 = 25% speed, 1.0 = normal speed. Pitch is always 0 (no pitch shift).
    func setRate(_ rate: Float) {
        let clamped = max(0.25, min(1.0, rate))
        node.rate = clamped
        node.pitch = 0.0
    }

    var currentRate: Float {
        node.rate
    }
}

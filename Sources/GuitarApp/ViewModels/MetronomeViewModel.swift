import Foundation
import Combine
import AVFoundation

@MainActor
final class MetronomeViewModel: ObservableObject {

    @Published var isRunning: Bool = false
    @Published var volume: Float = 0.8
    @Published var detectedBPM: Double? = nil
    @Published var isDetecting: Bool = false

    private let metronomeEngine: MetronomeEngine

    // Mirror ContentView state so we stay in sync without owning it.
    private(set) var bpm: Double = 120
    private(set) var beatsPerBar: Int = 4
    private(set) var playbackRate: Float = 1.0

    init(audioEngine: AudioEngine) {
        self.metronomeEngine = MetronomeEngine(engine: audioEngine.engine)
    }

    // MARK: - Transport sync

    /// Called when playback starts — starts the click track if the metronome is on.
    func onPlaybackStarted(bpm: Double, beatsPerBar: Int, playbackRate: Float) {
        self.bpm = bpm
        self.beatsPerBar = beatsPerBar
        self.playbackRate = playbackRate
        if isRunning {
            metronomeEngine.start(bpm: bpm, beatsPerBar: beatsPerBar, playbackRate: playbackRate)
        }
    }

    /// Called when playback pauses or stops.
    func onPlaybackStopped() {
        metronomeEngine.stop()
    }

    /// Called when BPM or time signature changes (while playing or not).
    func onBPMChanged(bpm: Double, beatsPerBar: Int) {
        self.bpm = bpm
        self.beatsPerBar = beatsPerBar
        metronomeEngine.beatsPerBar = beatsPerBar
        metronomeEngine.updateBPM(bpm)
    }

    /// Called when playback rate (speed) changes.
    func onRateChanged(_ rate: Float) {
        playbackRate = rate
        metronomeEngine.updatePlaybackRate(rate)
    }

    // MARK: - Toggle

    func toggle(bpm: Double, beatsPerBar: Int, playbackRate: Float) {
        isRunning.toggle()
        self.bpm = bpm
        self.beatsPerBar = beatsPerBar
        self.playbackRate = playbackRate
        metronomeEngine.volume = volume

        if isRunning {
            metronomeEngine.start(bpm: bpm, beatsPerBar: beatsPerBar, playbackRate: playbackRate)
        } else {
            metronomeEngine.stop()
        }
    }

    // MARK: - Volume

    func setVolume(_ v: Float) {
        volume = v
        metronomeEngine.volume = v
    }

    // MARK: - BPM Detection

    func detectBPM(from buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard !isDetecting else { return }
        isDetecting = true
        detectedBPM = nil

        Task.detached(priority: .utility) { [weak self] in
            let detector = BeatDetector(sampleRate: sampleRate)
            let result = await detector.detect(from: buffer)
            await MainActor.run { [weak self] in
                self?.detectedBPM = result
                self?.isDetecting = false
            }
        }
    }
}

import AVFoundation
import Foundation

final class AudioEngine {

    private let engine = AVAudioEngine()
    private(set) var playerNode = AVAudioPlayerNode()
    private(set) var timePitchNode = AVAudioUnitTimePitch()

    private(set) var audioFile: AVAudioFile?
    private(set) var currentTrack: AudioTrack?

    private var timer: Timer?
    private var _currentTime: TimeInterval = 0
    var currentTime: TimeInterval { _currentTime }

    /// The audio-file time that was current when playerNode.play() was last called.
    /// computeCurrentTime() adds this offset to the raw sample-since-play-start count.
    private var _playStartTime: TimeInterval = 0

    // Called on main thread when currentTime updates
    var onTimeUpdate: ((TimeInterval) -> Void)?
    var onPlaybackEnded: (() -> Void)?

    private let serialQueue = DispatchQueue(label: "com.guitarapp.audioengine", qos: .userInteractive)

    let loopController = LoopController()

    init() {
        setupGraph()
    }

    private func setupGraph() {
        engine.attach(playerNode)
        engine.attach(timePitchNode)

        engine.connect(playerNode, to: timePitchNode, format: nil)
        engine.connect(timePitchNode, to: engine.mainMixerNode, format: nil)

        timePitchNode.pitch = 0.0
        timePitchNode.rate = 1.0

        loopController.playerNode = playerNode
    }

    func prepare(with url: URL) throws -> AudioTrack {
        stop()
        loopController.disable()

        let loader = AudioFileLoader()
        let result = try loader.load(url: url)
        self.currentTrack = result.track
        self.audioFile = result.audioFile
        loopController.audioFile = result.audioFile

        if !engine.isRunning {
            try engine.start()
        }

        return result.track
    }

    func play() {
        guard let audioFile = audioFile else { return }

        if playerNode.isPlaying { return }

        if loopController.isLooping {
            // Loop mode: schedule the first loop segment
            loopController.scheduleFirstSegment()
        } else {
            // Normal mode: schedule from current position to end of file
            if _currentTime <= 0 {
                scheduleFile(from: 0, audioFile: audioFile)
            }
        }

        playerNode.play()
        startTimer()
    }

    func pause() {
        playerNode.pause()
        stopTimer()
        _currentTime = computeCurrentTime()
    }

    func stop() {
        playerNode.stop()
        stopTimer()
        _currentTime = 0
    }

    func seek(to time: TimeInterval) {
        guard let audioFile = audioFile, let track = currentTrack else { return }

        let wasPlaying = playerNode.isPlaying

        playerNode.stop()
        stopTimer()

        let clampedTime = max(0, min(time, track.duration))
        _currentTime = clampedTime

        if loopController.isLooping {
            loopController.scheduleFirstSegment()
        } else {
            scheduleFile(from: clampedTime, audioFile: audioFile)
        }

        if wasPlaying {
            playerNode.play()
            startTimer()
        }
    }

    func setRate(_ rate: Float) {
        let clamped = max(0.25, min(1.0, rate))
        timePitchNode.rate = clamped
        timePitchNode.pitch = 0.0
    }

    // MARK: - Loop control

    func enableLoop(region: LoopRegion) {
        guard let audioFile = audioFile else { return }
        let wasPlaying = playerNode.isPlaying

        playerNode.stop()
        stopTimer()
        _currentTime = region.inPoint

        loopController.enable(region: region, audioFile: audioFile)
        loopController.scheduleFirstSegment()

        if wasPlaying {
            playerNode.play()
            startTimer()
        }
    }

    func disableLoop() {
        guard let audioFile = audioFile else { return }
        let wasPlaying = playerNode.isPlaying
        let currentPos = _currentTime

        playerNode.stop()
        stopTimer()

        loopController.disable()
        scheduleFile(from: currentPos, audioFile: audioFile)

        if wasPlaying {
            playerNode.play()
            startTimer()
        }
    }

    func updateLoopRegion(_ region: LoopRegion) {
        guard let audioFile = audioFile else { return }
        let wasPlaying = playerNode.isPlaying

        playerNode.stop()
        stopTimer()

        loopController.enable(region: region, audioFile: audioFile)
        loopController.scheduleFirstSegment()

        if wasPlaying {
            playerNode.play()
            startTimer()
        }
    }

    // MARK: - Private helpers

    private func scheduleFile(from time: TimeInterval, audioFile: AVAudioFile) {
        guard let track = currentTrack else { return }
        let sampleRate = audioFile.fileFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)
        let remainingFrames = AVAudioFrameCount(max(0, Int64(track.frameCount) - startFrame))

        guard remainingFrames > 0 else { return }

        playerNode.scheduleSegment(
            audioFile,
            startingFrame: startFrame,
            frameCount: remainingFrames,
            at: nil,
            completionCallbackType: .dataRendered
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.onPlaybackEnded?()
            }
        }
    }

    private func startTimer() {
        stopTimer()
        // Snapshot the seek offset at the moment playback begins so
        // computeCurrentTime() can add it to the raw sample-since-play-start count.
        _playStartTime = _currentTime
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let t = self.computeCurrentTime()
            self._currentTime = t
            self.onTimeUpdate?(t)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func computeCurrentTime() -> TimeInterval {
        guard playerNode.isPlaying,
              let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime),
              let track = currentTrack else {
            return _currentTime
        }
        let sampleTime = playerTime.sampleTime
        let sampleRate = playerTime.sampleRate
        guard sampleTime >= 0 && sampleRate > 0 else { return _currentTime }

        // sampleTime counts samples rendered since playerNode.play() was last called —
        // it always starts from 0 regardless of seek position. Add _playStartTime to
        // get the correct audio-file position.
        let elapsedSincePlay = Double(sampleTime) / sampleRate

        if loopController.isLooping, let region = loopController.region {
            let loopDuration = region.outPoint - region.inPoint
            guard loopDuration > 0 else { return _currentTime }
            let positionInLoop = elapsedSincePlay.truncatingRemainder(dividingBy: loopDuration)
            return region.inPoint + positionInLoop
        }

        return min(_playStartTime + elapsedSincePlay, track.duration)
    }
}

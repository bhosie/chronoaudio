import AVFoundation
import Accelerate

/// Plays a click track through the shared AVAudioEngine.
///
/// The clickNode is attached to the engine by AudioEngine.setupGraph() before
/// engine.start() is ever called. MetronomeEngine never modifies the audio graph.
final class MetronomeEngine {

    // MARK: - State

    private let engine: AVAudioEngine
    private let clickNode: AVAudioPlayerNode

    private(set) var isRunning = false
    var bpm: Double = 120 { didSet { if isRunning { restart() } } }
    var volume: Float = 0.8 { didSet { clickNode.volume = volume } }
    var playbackRate: Float = 1.0

    private let lookaheadBeats = 8
    private var scheduledUpToSampleTime: AVAudioFramePosition = 0
    private var schedulerTimer: Timer?
    private let scheduleQueue = DispatchQueue(label: "com.guitarapp.metronome", qos: .userInteractive)

    private var accentBuffer: AVAudioPCMBuffer?
    private var normalBuffer: AVAudioPCMBuffer?
    private var clickFormat: AVAudioFormat?

    private var beatIndex: Int = 0
    var beatsPerBar: Int = 4

    // MARK: - Init

    init(engine: AVAudioEngine, clickNode: AVAudioPlayerNode) {
        self.engine = engine
        self.clickNode = clickNode
    }

    // MARK: - Public API

    func start(bpm: Double, beatsPerBar: Int, playbackRate: Float) {
        guard engine.isRunning else { return }

        self.bpm = bpm
        self.beatsPerBar = beatsPerBar
        self.playbackRate = playbackRate
        self.beatIndex = 0
        self.scheduledUpToSampleTime = 0

        buildClickBuffers()

        clickNode.volume = volume
        clickNode.play()
        isRunning = true

        scheduleQueue.async { [weak self] in self?.scheduleBeats() }
        startSchedulerTimer()
    }

    func stop() {
        schedulerTimer?.invalidate()
        schedulerTimer = nil
        clickNode.stop()
        isRunning = false
        scheduledUpToSampleTime = 0
        beatIndex = 0
    }

    func updateBPM(_ newBPM: Double) {
        bpm = newBPM
    }

    func updatePlaybackRate(_ rate: Float) {
        playbackRate = rate
        if isRunning { restart() }
    }

    // MARK: - Private

    private func restart() {
        let savedBPM = bpm
        let savedBeats = beatsPerBar
        let savedRate = playbackRate
        stop()
        start(bpm: savedBPM, beatsPerBar: savedBeats, playbackRate: savedRate)
    }

    private func scheduleBeats() {
        guard let format = clickFormat,
              let accentBuf = accentBuffer,
              let normalBuf = normalBuffer else { return }

        let effectiveBPS = bpm / 60.0 * Double(playbackRate)
        guard effectiveBPS > 0 else { return }
        let framesPerBeat = AVAudioFramePosition(format.sampleRate / effectiveBPS)

        if scheduledUpToSampleTime == 0 {
            // We cannot use engine.outputNode.lastRenderTime.sampleTime as the
            // anchor because it reflects the last completed render cycle, which
            // can be several seconds behind wall-clock time when the engine has
            // been running but idle (no audio scheduled). Scheduling relative to
            // that stale timestamp means the first N beats are already in the
            // past and get silently dropped, causing a multi-second delay before
            // the first audible click.
            //
            // Instead, anchor off the current host time by converting it to a
            // sample time via extrapolateTime(fromAnchor:) using the output
            // node's most recent render timestamp as the reference frame. Then
            // add a small fixed offset (~100ms) to give the scheduler time to
            // queue the buffer before the hardware reaches that timestamp.
            guard let anchorTime = engine.outputNode.lastRenderTime else { return }
            let nowHostTime = mach_absolute_time()
            let nowAVTime = AVAudioTime(hostTime: nowHostTime)
            guard let nowSampleTime = nowAVTime.extrapolateTime(fromAnchor: anchorTime) else {
                // Fallback: anchor directly off lastRenderTime.
                let startOffsetFrames = AVAudioFramePosition(format.sampleRate * 0.1)
                scheduledUpToSampleTime = anchorTime.sampleTime + startOffsetFrames
                return
            }
            let startOffsetFrames = AVAudioFramePosition(format.sampleRate * 0.1)
            scheduledUpToSampleTime = nowSampleTime.sampleTime + startOffsetFrames
        }

        for _ in 0 ..< lookaheadBeats {
            let buf = (beatIndex % beatsPerBar == 0) ? accentBuf : normalBuf
            let time = AVAudioTime(sampleTime: scheduledUpToSampleTime, atRate: format.sampleRate)
            clickNode.scheduleBuffer(buf, at: time, options: [], completionHandler: nil)
            scheduledUpToSampleTime += framesPerBeat
            beatIndex += 1
        }
    }

    private func startSchedulerTimer() {
        schedulerTimer?.invalidate()
        schedulerTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.scheduleQueue.async { self.scheduleBeats() }
        }
    }

    private func buildClickBuffers() {
        // Use the clickNode's actual output format so channel counts match.
        let outputFormat = clickNode.outputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 44100
        let channelCount = outputFormat.channelCount > 0 ? outputFormat.channelCount : 2
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount) else { return }
        clickFormat = format
        accentBuffer = makeClickBuffer(format: format, frequency: 1200, durationMs: 12, amplitude: 0.9)
        normalBuffer = makeClickBuffer(format: format, frequency: 800,  durationMs: 10, amplitude: 0.6)
    }

    private func makeClickBuffer(format: AVAudioFormat,
                                  frequency: Double,
                                  durationMs: Double,
                                  amplitude: Float) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(format.sampleRate * durationMs / 1000.0)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        let channelData = buffer.floatChannelData![0]
        let sr = format.sampleRate
        for i in 0 ..< Int(frameCount) {
            let t = Double(i) / sr
            let envelope = exp(-t * 200.0)
            let sine = sin(2.0 * Double.pi * frequency * t)
            channelData[i] = Float(amplitude) * Float(envelope * sine)
        }
        return buffer
    }
}

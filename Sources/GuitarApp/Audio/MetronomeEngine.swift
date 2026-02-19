import AVFoundation
import Accelerate

/// Plays a click track through the shared AVAudioEngine.
///
/// Click scheduling strategy:
///   - A dedicated AVAudioPlayerNode is attached to the shared engine.
///   - When started, we schedule a series of short click buffers at precise
///     sample offsets so beats land exactly on time regardless of playback speed.
///   - We re-schedule lookahead clicks on a Timer so the buffer never runs dry.
///   - BPM and volume can be changed on-the-fly; a change reschedules from the
///     next beat boundary.
final class MetronomeEngine {

    // MARK: - State

    private let engine: AVAudioEngine
    private let clickNode = AVAudioPlayerNode()
    private var isAttached = false

    private(set) var isRunning = false
    var bpm: Double = 120 { didSet { if isRunning { restart() } } }
    var volume: Float = 0.8 { didSet { clickNode.volume = volume } }
    var playbackRate: Float = 1.0  // mirrors AudioEngine rate; affects click interval

    // How many beats to pre-schedule ahead of "now"
    private let lookaheadBeats = 8
    private var scheduledUpToSampleTime: AVAudioFramePosition = 0
    private var schedulerTimer: Timer?

    // Cached click buffers (accent on beat 1, normal for other beats)
    private var accentBuffer: AVAudioPCMBuffer?
    private var normalBuffer: AVAudioPCMBuffer?
    private var clickFormat: AVAudioFormat?

    // Beat counter for accenting beat 1 in the time signature
    private var beatIndex: Int = 0
    var beatsPerBar: Int = 4

    // MARK: - Init

    init(engine: AVAudioEngine) {
        self.engine = engine
    }

    // MARK: - Public API

    func start(bpm: Double, beatsPerBar: Int, playbackRate: Float) {
        self.bpm = bpm
        self.beatsPerBar = beatsPerBar
        self.playbackRate = playbackRate
        self.beatIndex = 0

        attachIfNeeded()
        buildClickBuffers()

        clickNode.volume = volume
        clickNode.play()
        isRunning = true

        scheduleBeats()
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
        bpm = newBPM  // didSet calls restart() if running
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

    private func attachIfNeeded() {
        guard !isAttached else { return }
        engine.attach(clickNode)
        engine.connect(clickNode, to: engine.mainMixerNode, format: nil)
        isAttached = true
    }

    // MARK: - Beat scheduling

    /// Schedule the next `lookaheadBeats` worth of clicks starting from
    /// `scheduledUpToSampleTime` (or "now" if not started yet).
    private func scheduleBeats() {
        guard let format = clickFormat,
              let accentBuf = accentBuffer,
              let normalBuf = normalBuffer else { return }

        // Effective BPM accounting for playback rate (slower rate = wider beat interval)
        let effectiveBPS = bpm / 60.0 * Double(playbackRate)
        let framesPerBeat = AVAudioFramePosition(format.sampleRate / effectiveBPS)

        // Anchor to the node's current sample time if we haven't started yet
        if scheduledUpToSampleTime == 0 {
            if let nodeTime = clickNode.lastRenderTime {
                scheduledUpToSampleTime = nodeTime.sampleTime + framesPerBeat
            } else {
                scheduledUpToSampleTime = framesPerBeat
            }
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
        // Refresh every ~200 ms — well within the lookahead window at any sensible BPM
        schedulerTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.scheduleBeats()
        }
    }

    // MARK: - Click buffer synthesis

    /// Synthesise short sinusoidal click buffers for accent (beat 1) and normal beats.
    private func buildClickBuffers() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else { return }
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
            // Sine with exponential decay envelope
            let envelope = exp(-t * 200.0)
            let sine = sin(2.0 * Double.pi * frequency * t)
            channelData[i] = Float(amplitude) * Float(envelope * sine)
        }
        return buffer
    }
}

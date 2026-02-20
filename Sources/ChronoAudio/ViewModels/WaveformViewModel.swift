import Foundation
import Combine

@MainActor
final class WaveformViewModel: ObservableObject {
    // MARK: - Waveform data
    @Published var waveformSamples: [Float] = []

    // MARK: - Zoom / viewport  (audio-file seconds)
    /// 1.0 = full track visible, 2.0 = half the track visible, etc. Clamped [1, 32].
    @Published var zoomFactor: Double = 1.0 {
        didSet { updateViewport() }
    }
    /// Left edge of the visible window, in audio-file seconds.
    @Published private(set) var viewStart: Double = 0
    /// Right edge of the visible window, in audio-file seconds.
    @Published private(set) var viewEnd: Double = 0

    // MARK: - Normalised positions *within the visible window* (0 = left edge, 1 = right edge)
    @Published var playheadPosition: CGFloat = 0
    @Published var loopInPosition:   CGFloat = 0
    @Published var loopOutPosition:  CGFloat = 1
    @Published var loopEnabled:      Bool    = false

    // MARK: - Visible sample slice
    /// Sub-array of waveformSamples that corresponds to [viewStart, viewEnd].
    @Published private(set) var visibleSamples: [Float] = []

    // MARK: - Private state
    private let sampler = WaveformSampler()
    private var cancellables = Set<AnyCancellable>()
    private var trackDuration: Double = 0
    private var currentTime: Double = 0

    // MARK: - Public API

    func observe(_ playerVM: PlayerViewModel) {
        // Re-sample waveform when track (or its pcmBuffer) changes.
        playerVM.$track
            .receive(on: RunLoop.main)
            .sink { [weak self] track in
                guard let self else { return }
                guard let track else {
                    self.waveformSamples = []
                    self.trackDuration = 0
                    self.resetZoom()
                    return
                }
                self.trackDuration = track.duration
                guard let buffer = track.pcmBuffer else {
                    self.waveformSamples = []
                    self.resetZoom()
                    return
                }
                Task { [weak self] in
                    guard let self else { return }
                    let samples = await self.sampler.sample(buffer: buffer, targetCount: 2048)
                    await MainActor.run {
                        self.waveformSamples = samples
                        self.updateViewport()
                    }
                }
            }
            .store(in: &cancellables)

        // Update normalised positions whenever playback state changes.
        playerVM.$playbackState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                guard let track = playerVM.track, track.duration > 0 else {
                    self.playheadPosition = 0
                    return
                }
                self.currentTime = state.currentTime
                self.trackDuration = track.duration

                // Auto-scroll: keep playhead inside the visible window when zoomed.
                self.autoScrollIfNeeded(currentTime: state.currentTime)

                if let region = state.loopRegion {
                    self.loopInPosition  = self.normalise(audioSeconds: region.inPoint)
                    self.loopOutPosition = self.normalise(audioSeconds: region.outPoint)
                    self.loopEnabled     = region.isEnabled
                } else {
                    self.loopInPosition  = 0
                    self.loopOutPosition = 1
                    self.loopEnabled     = false
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Zoom control

    /// Adjust zoom by a multiplicative factor (e.g. 1.2 to zoom in, 1/1.2 to zoom out).
    /// Anchors the zoom on the current playhead position so it stays centred.
    func adjustZoom(factor: Double, anchorSeconds: Double? = nil) {
        let anchor = anchorSeconds ?? currentTime
        let newZoom = (zoomFactor * factor).clamped(to: 1.0...32.0)
        zoomFactor = newZoom
        // Re-centre viewport on anchor after zoom changes window size.
        centreViewport(on: anchor)
    }

    /// Reset zoom to 1× (full track visible).
    func resetZoom() {
        zoomFactor = 1.0
        viewStart = 0
        viewEnd = trackDuration
        updatePositions()
        updateVisibleSamples()
    }

    // MARK: - Coordinate conversion

    /// Converts a fraction of the *visible* window (0–1) to audio-file seconds.
    func audioSeconds(fromViewFraction fraction: Double) -> Double {
        let window = viewEnd - viewStart
        return (viewStart + fraction * window).clamped(to: 0...trackDuration)
    }

    // MARK: - Private helpers

    private func updateViewport() {
        guard trackDuration > 0 else {
            viewStart = 0; viewEnd = 0
            playheadPosition = 0
            visibleSamples = []
            return
        }
        // Keep viewport centred on current playhead; clamp to track bounds.
        centreViewport(on: currentTime)
    }

    private func centreViewport(on anchorSeconds: Double) {
        guard trackDuration > 0 else { return }
        let windowDuration = trackDuration / zoomFactor
        var start = anchorSeconds - windowDuration / 2
        var end   = start + windowDuration

        // Clamp to [0, trackDuration]
        if start < 0 { start = 0; end = windowDuration }
        if end > trackDuration { end = trackDuration; start = max(0, end - windowDuration) }

        viewStart = start
        viewEnd   = end
        updatePositions()
        updateVisibleSamples()
    }

    private func autoScrollIfNeeded(currentTime: Double) {
        guard trackDuration > 0, zoomFactor > 1 else {
            // At 1× just update positions — no scroll needed.
            playheadPosition = CGFloat(currentTime / trackDuration)
            return
        }
        let window = viewEnd - viewStart
        let margin = window * 0.05  // 5% margin before edge triggers scroll
        let newPlayhead = currentTime

        if newPlayhead < viewStart + margin || newPlayhead > viewEnd - margin {
            centreViewport(on: newPlayhead)
        } else {
            updatePositions()
        }
    }

    private func updatePositions() {
        playheadPosition = CGFloat(normalise(audioSeconds: currentTime))
        // Loop positions are updated in the playbackState sink; call normalise there.
        // But we need to keep them in sync when viewport shifts without a state change.
    }

    private func updateVisibleSamples() {
        guard !waveformSamples.isEmpty, trackDuration > 0 else {
            visibleSamples = waveformSamples
            return
        }
        let total = waveformSamples.count
        let startFrac = viewStart / trackDuration
        let endFrac   = viewEnd   / trackDuration
        let lo = Int((startFrac * Double(total)).clamped(to: 0...Double(total - 1)))
        let hi = Int((endFrac   * Double(total)).clamped(to: 0...Double(total))).clamped(to: lo...total)
        visibleSamples = lo < hi ? Array(waveformSamples[lo..<hi]) : []
    }

    /// Map audio-file seconds → fraction within the current visible window (0–1).
    private func normalise(audioSeconds: Double) -> Double {
        let window = viewEnd - viewStart
        guard window > 0 else { return 0 }
        return ((audioSeconds - viewStart) / window).clamped(to: 0...1)
    }
}

// MARK: - Comparable clamping helpers

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

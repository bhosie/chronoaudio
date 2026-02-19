import Foundation
import Combine

@MainActor
final class WaveformViewModel: ObservableObject {
    @Published var waveformSamples: [Float] = []
    @Published var playheadPosition: CGFloat = 0
    @Published var loopInPosition: CGFloat = 0
    @Published var loopOutPosition: CGFloat = 1

    private let sampler = WaveformSampler()
    private var cancellables = Set<AnyCancellable>()

    func observe(_ playerVM: PlayerViewModel) {
        // Re-sample waveform when track (or its pcmBuffer) changes.
        // Phase 1: track arrives with pcmBuffer=nil → clear samples (show empty waveform).
        // Phase 2: track is republished with pcmBuffer filled → sample and display.
        playerVM.$track
            .receive(on: RunLoop.main)
            .sink { [weak self] track in
                guard let self else { return }
                guard let track = track else {
                    self.waveformSamples = []
                    return
                }
                guard let buffer = track.pcmBuffer else {
                    // Buffer not ready yet — clear so the canvas shows an empty state.
                    self.waveformSamples = []
                    return
                }
                Task { [weak self] in
                    guard let self else { return }
                    let samples = await self.sampler.sample(buffer: buffer, targetCount: 2048)
                    await MainActor.run {
                        self.waveformSamples = samples
                    }
                }
            }
            .store(in: &cancellables)

        // Update normalized playhead position
        playerVM.$playbackState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                guard let track = playerVM.track, track.duration > 0 else {
                    self.playheadPosition = 0
                    return
                }
                self.playheadPosition = CGFloat(state.currentTime / track.duration)

                if let region = state.loopRegion {
                    self.loopInPosition = CGFloat(region.inPoint / track.duration)
                    self.loopOutPosition = CGFloat(region.outPoint / track.duration)
                } else {
                    self.loopInPosition = 0
                    self.loopOutPosition = 1
                }
            }
            .store(in: &cancellables)
    }
}

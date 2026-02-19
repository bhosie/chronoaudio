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
        // Re-sample waveform when track changes
        playerVM.$track
            .receive(on: RunLoop.main)
            .sink { [weak self] track in
                guard let self else { return }
                if let track = track, let buffer = track.pcmBuffer {
                    Task { [weak self] in
                        guard let self else { return }
                        let samples = await self.sampler.sample(buffer: buffer, targetCount: 2048)
                        await MainActor.run {
                            self.waveformSamples = samples
                        }
                    }
                } else {
                    self.waveformSamples = []
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

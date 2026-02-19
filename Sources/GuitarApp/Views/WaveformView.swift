import SwiftUI

struct WaveformView: View {
    @ObservedObject var waveformVM: WaveformViewModel
    @ObservedObject var playerVM: PlayerViewModel

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !playerVM.isPlaying)) { _ in
                Canvas { ctx, size in
                    WaveformRenderer.draw(
                        context: ctx,
                        size: size,
                        samples: waveformVM.waveformSamples,
                        playheadPosition: waveformVM.playheadPosition,
                        loopInPosition: waveformVM.loopInPosition,
                        loopOutPosition: waveformVM.loopOutPosition
                    )
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard playerVM.track != nil else { return }
                        let fraction = Double(value.location.x / geo.size.width)
                            .clamped(to: 0...1)
                        guard let duration = playerVM.track?.duration else { return }
                        playerVM.seek(to: fraction * duration)
                    }
            )
        }
        .frame(minHeight: 120)
        .cornerRadius(8)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

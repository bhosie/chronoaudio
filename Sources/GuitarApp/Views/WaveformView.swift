import SwiftUI

struct WaveformView: View {
    @ObservedObject var waveformVM: WaveformViewModel
    @ObservedObject var playerVM: PlayerViewModel

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Waveform canvas (always present, hidden while loading)
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
                .opacity(isLoadingWaveform ? 0 : 1)

                // Loading state: track is ready but waveform hasn't decoded yet
                if isLoadingWaveform {
                    WaveformLoadingView()
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

    /// True only during the window between fast-path track load and waveform decode completing.
    private var isLoadingWaveform: Bool {
        playerVM.track != nil && waveformVM.waveformSamples.isEmpty
    }
}

// MARK: - Loading placeholder

private struct WaveformLoadingView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                drawBars(context: ctx, size: size)
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.9)
                .repeatForever(autoreverses: true)
            ) {
                phase = 1
            }
        }
    }

    private func drawBars(context: GraphicsContext, size: CGSize) {
        let barCount = 48
        let barWidth: CGFloat = max(1, (size.width / CGFloat(barCount)) * 0.55)
        let spacing = size.width / CGFloat(barCount)
        let midY = size.height / 2

        for i in 0..<barCount {
            // Staggered sine wave using pre-computed phase
            let t = CGFloat(i) / CGFloat(barCount - 1)
            // Two overlapping waves create an organic shimmer
            let height = sin(t * .pi * 3 + phase * .pi * 2) * 0.3 + 0.15
            let barHeight = max(3, size.height * abs(height))
            let x = CGFloat(i) * spacing + spacing / 2

            let rect = CGRect(
                x: x - barWidth / 2,
                y: midY - barHeight / 2,
                width: barWidth,
                height: barHeight
            )
            let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)

            // Fade opacity in a wave pattern for the shimmer effect
            let opacity = 0.12 + 0.18 * abs(sin(t * .pi * 2 + phase * .pi * 2))
            context.fill(path, with: .color(.white.opacity(opacity)))
        }
    }
}

// MARK: - Helpers

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

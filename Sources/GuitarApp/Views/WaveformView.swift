import SwiftUI

// MARK: - Drag target resolved at gesture start

private enum DragTarget {
    case loopIn
    case loopOut
    case seek
}

struct WaveformView: View {
    @ObservedObject var waveformVM: WaveformViewModel
    @ObservedObject var playerVM: PlayerViewModel

    /// Which element the current drag is targeting (resolved on gesture start).
    @State private var activeDrag: DragTarget = .seek

    /// Hit-test radius in points for snapping to a marker.
    private let markerHitRadius: CGFloat = 14

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
                            loopOutPosition: waveformVM.loopOutPosition,
                            loopEnabled: waveformVM.loopEnabled
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
                        let x = value.location.x
                        let width = geo.size.width

                        // On the very first event of this gesture, lock in the target.
                        if value.translation == .zero {
                            activeDrag = resolveDragTarget(x: x, width: width)
                        }

                        let fraction = Double(x / width).clamped(to: 0...1)
                        guard let duration = playerVM.track?.duration else { return }

                        switch activeDrag {
                        case .loopIn:
                            playerVM.setLoopIn(fraction * duration)
                        case .loopOut:
                            playerVM.setLoopOut(fraction * duration)
                        case .seek:
                            playerVM.seek(to: fraction * duration)
                        }
                    }
            )
        }
        .frame(minHeight: 120)
        .cornerRadius(8)
    }

    // MARK: - Helpers

    /// True only during the window between fast-path track load and waveform decode completing.
    private var isLoadingWaveform: Bool {
        playerVM.track != nil && waveformVM.waveformSamples.isEmpty
    }

    /// Returns the drag target based on proximity to existing loop markers.
    /// Falls back to .seek if no region is set or touch is not near a marker.
    private func resolveDragTarget(x: CGFloat, width: CGFloat) -> DragTarget {
        guard playerVM.playbackState.loopRegion != nil else { return .seek }

        let inX  = waveformVM.loopInPosition  * width
        let outX = waveformVM.loopOutPosition * width

        if abs(x - inX) <= markerHitRadius  { return .loopIn  }
        if abs(x - outX) <= markerHitRadius { return .loopOut }
        return .seek
    }
}

// MARK: - Loading placeholder

private struct WaveformLoadingView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { _ in
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
            let t = CGFloat(i) / CGFloat(barCount - 1)
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

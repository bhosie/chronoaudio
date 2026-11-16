import SwiftUI
import AppKit

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

    /// Accumulated magnification while a pinch gesture is live.
    @State private var liveMagnification: CGFloat = 1.0

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
                            samples: waveformVM.visibleSamples,
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

                // Zoom indicator — shown briefly when zoomed in
                if waveformVM.zoomFactor > 1.01 {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ZoomBadge(zoom: waveformVM.zoomFactor)
                                .padding(8)
                        }
                    }
                }
            }
            // MARK: Drag gesture (seek / loop marker drag)
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

                        // Convert view-fraction → audio seconds via the visible window.
                        let fraction = Double(x / width).clamped(to: 0...1)
                        let audioTime = waveformVM.audioSeconds(fromViewFraction: fraction)

                        switch activeDrag {
                        case .loopIn:
                            playerVM.setLoopIn(audioTime)
                        case .loopOut:
                            playerVM.setLoopOut(audioTime)
                        case .seek:
                            playerVM.seek(to: audioTime)
                        }
                    }
            )
            // MARK: Pinch-to-zoom
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        // `value` is the cumulative scale since gesture began.
                        // We apply the delta relative to the last known value.
                        let delta = Double(value / liveMagnification)
                        liveMagnification = value
                        // Anchor zoom on the centre of the view (in audio seconds).
                        let anchorFrac = 0.5
                        let anchorSec = waveformVM.audioSeconds(fromViewFraction: anchorFrac)
                        waveformVM.adjustZoom(factor: delta, anchorSeconds: anchorSec)
                    }
                    .onEnded { _ in
                        liveMagnification = 1.0
                    }
            )
            // Double-tap to reset zoom
            .onTapGesture(count: 2) {
                waveformVM.resetZoom()
            }
            // MARK: Cmd+/Cmd- keyboard zoom (via AppCommands menu)
            .onReceive(NotificationCenter.default.publisher(for: .zoomInRequested)) { _ in
                waveformVM.adjustZoom(factor: 2.0)
            }
            .onReceive(NotificationCenter.default.publisher(for: .zoomOutRequested)) { _ in
                waveformVM.adjustZoom(factor: 0.5)
            }
            .onReceive(NotificationCenter.default.publisher(for: .zoomResetRequested)) { _ in
                waveformVM.resetZoom()
            }
            // MARK: Mouse wheel / trackpad scroll to zoom, anchored on the pointer
            .overlay(
                ScrollWheelZoomArea { deltaY, xFraction in
                    guard playerVM.track != nil else { return }
                    let sensitivity = 0.015
                    let factor = pow(1.0 + sensitivity, Double(deltaY))
                    let anchorSeconds = waveformVM.audioSeconds(fromViewFraction: Double(xFraction))
                    waveformVM.adjustZoom(factor: factor, anchorSeconds: anchorSeconds)
                }
                .allowsHitTesting(false)
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

// MARK: - Zoom badge

private struct ZoomBadge: View {
    let zoom: Double

    var body: some View {
        Text(String(format: "%.1f×", zoom))
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.55))
            .clipShape(Capsule())
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

// MARK: - Scroll wheel zoom

/// Invisible overlay that installs a local NSEvent monitor for scroll-wheel events
/// (mouse wheel and trackpad two-finger scroll) and reports the vertical delta plus
/// the horizontal pointer position (as a 0–1 fraction of the view's width) while the
/// pointer is over this view's bounds.
///
/// A local event monitor is used instead of overriding `scrollWheel(with:)` directly
/// so this view can stay out of AppKit's hit-test chain (`allowsHitTesting(false)`)
/// and avoid stealing mouseDown from the seek/loop-marker drag and pinch gestures
/// layered on top of it.
private struct ScrollWheelZoomArea: NSViewRepresentable {
    let onScroll: (_ deltaY: CGFloat, _ xFraction: CGFloat) -> Void

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.onScroll = onScroll
    }

    final class MonitorView: NSView {
        var onScroll: ((CGFloat, CGFloat) -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            installMonitor()
        }

        private func installMonitor() {
            removeMonitor()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let window = self.window, event.window == window else { return event }
                let locationInView = self.convert(event.locationInWindow, from: nil)
                guard self.bounds.contains(locationInView), self.bounds.width > 0 else { return event }

                let xFraction = (locationInView.x / self.bounds.width).clamped(to: 0...1)
                self.onScroll?(event.scrollingDeltaY, xFraction)
                return nil
            }
        }

        private func removeMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        deinit { removeMonitor() }
    }
}

// MARK: - Helpers

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}


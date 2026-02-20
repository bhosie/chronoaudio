import SwiftUI

/// A horizontal ruler that shows bars and beat subdivisions across the *visible* time window.
/// Bar numbers are drawn above major tick lines; beat subdivisions are shorter ticks.
/// A needle marks the current playhead position.
///
/// All positions are in audio-file time (seconds), independent of playback rate.
struct RulerView: View {
    /// Current playhead position in audio-file seconds.
    let currentTime: TimeInterval
    /// Total track duration in audio-file seconds.
    let trackDuration: TimeInterval
    /// Tempo in beats per minute (audio-file tempo, not scaled by playback rate).
    let bpm: Double
    /// Number of beats per bar (e.g. 4 for 4/4, 6 for 6/8).
    let beatsPerBar: Int
    /// Beat unit: 4 = quarter note, 8 = eighth note. Determines how long one beat lasts.
    let beatUnit: Int
    /// Left edge of the visible waveform window, in audio-file seconds.
    let viewStart: Double
    /// Right edge of the visible waveform window, in audio-file seconds.
    let viewEnd: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            Canvas { ctx, size in
                guard size.width > 0, trackDuration > 0, bpm > 0 else { return }
                let windowDuration = viewEnd - viewStart
                guard windowDuration > 0 else { return }
                drawRuler(context: ctx, size: size, windowDuration: windowDuration)
            }
        }
        .frame(height: 28)
        .background(Color(white: 0.10))
    }

    // MARK: - Drawing

    private func drawRuler(context: GraphicsContext, size: CGSize, windowDuration: Double) {
        // BPM is always in quarter notes. Scale by (4 / beatUnit) so that e.g.
        // 6/8 at 120 BPM has eighth-note beats that are 0.25s long (not 0.5s).
        // beatUnit=4 → scale 1.0; beatUnit=8 → scale 0.5 (eighth note is half a quarter note).
        let secondsPerBeat = 60.0 / bpm * (4.0 / Double(max(beatUnit, 1)))
        let secondsPerBar  = secondsPerBeat * Double(beatsPerBar)

        // How many pixels does one second of the *visible window* occupy?
        let pixelsPerSecond = size.width / windowDuration

        // Helper: converts an audio-file time to an x position within this view.
        func xFor(t: Double) -> CGFloat {
            CGFloat((t - viewStart) * pixelsPerSecond)
        }

        // --- Beat subdivision ticks ---
        // Find the first beat that falls at or after viewStart.
        let firstBeatIndex = Int(floor(viewStart / secondsPerBeat))
        let lastBeatIndex  = Int(ceil(viewEnd   / secondsPerBeat))

        for beat in firstBeatIndex...max(firstBeatIndex, lastBeatIndex) {
            let t = Double(beat) * secondsPerBeat
            guard t >= viewStart - 0.001, t <= viewEnd + 0.001 else { continue }
            let x = xFor(t: t)
            guard x >= -1, x <= size.width + 1 else { continue }

            let isBeatOne = beat % beatsPerBar == 0
            let tickH: CGFloat = isBeatOne ? size.height : size.height * 0.35
            let tickColor = isBeatOne
                ? Color.white.opacity(0.25)
                : Color.white.opacity(0.10)

            var path = Path()
            path.move(to: CGPoint(x: x, y: size.height - tickH))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(tickColor), lineWidth: 1)
        }

        // --- Bar number labels ---
        // Only draw a label when there's enough horizontal space.
        let barWidthPx = secondsPerBar * pixelsPerSecond
        let labelEvery = max(1, Int(ceil(40.0 / barWidthPx)))

        let firstBarIndex = Int(floor(viewStart / secondsPerBar))
        let lastBarIndex  = Int(ceil(viewEnd   / secondsPerBar))

        for bar in firstBarIndex...max(firstBarIndex, lastBarIndex) {
            guard bar % labelEvery == 0 else { continue }
            let t = Double(bar) * secondsPerBar
            guard t <= trackDuration + 0.001 else { break }
            guard t >= viewStart - secondsPerBar, t <= viewEnd + secondsPerBar else { continue }
            let x = xFor(t: t)
            guard x >= -barWidthPx, x <= size.width + barWidthPx else { continue }

            let label = "\(bar + 1)"
            let resolved = context.resolve(Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.45)))
            let textSize = resolved.measure(in: size)

            let labelX = min(x + 2, size.width - textSize.width - 2)
            guard labelX >= -textSize.width else { continue }
            context.draw(resolved, at: CGPoint(x: labelX, y: 4), anchor: .topLeading)
        }

        // --- Playhead needle ---
        let headX = xFor(t: currentTime)
        // Only draw if the playhead is within the visible window.
        if headX >= 0, headX <= size.width {
            var needlePath = Path()
            needlePath.move(to: CGPoint(x: headX, y: 0))
            needlePath.addLine(to: CGPoint(x: headX, y: size.height))
            context.stroke(needlePath, with: .color(.white.opacity(0.85)), lineWidth: 1.5)

            var triangle = Path()
            triangle.move(to:    CGPoint(x: headX,     y: 7))
            triangle.addLine(to: CGPoint(x: headX - 4, y: 0))
            triangle.addLine(to: CGPoint(x: headX + 4, y: 0))
            triangle.closeSubpath()
            context.fill(triangle, with: .color(.white.opacity(0.9)))
        }
    }
}

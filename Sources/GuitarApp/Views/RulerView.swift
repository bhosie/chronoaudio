import SwiftUI

/// A horizontal ruler that shows bars and beat subdivisions across the track duration.
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
    /// Number of beats per bar (e.g. 4 for 4/4, 3 for 3/4).
    let beatsPerBar: Int

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            Canvas { ctx, size in
                guard size.width > 0, trackDuration > 0, bpm > 0 else { return }
                drawRuler(context: ctx, size: size)
            }
        }
        .frame(height: 28)
        .background(Color(white: 0.10))
    }

    // MARK: - Drawing

    private func drawRuler(context: GraphicsContext, size: CGSize) {
        let secondsPerBeat = 60.0 / bpm
        let secondsPerBar  = secondsPerBeat * Double(beatsPerBar)
        let totalBars = Int(ceil(trackDuration / secondsPerBar))

        // How many pixels does one second of audio occupy?
        let pixelsPerSecond = size.width / trackDuration

        // --- Beat subdivision ticks ---
        let totalBeats = Int(ceil(trackDuration / secondsPerBeat))
        for beat in 0...totalBeats {
            let t = Double(beat) * secondsPerBeat
            guard t <= trackDuration else { break }
            let x = t * pixelsPerSecond
            let isBeatOne = beat % beatsPerBar == 0
            // Beat-one ticks are taller; subdivision ticks are shorter
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
        // Only draw a label when there's enough horizontal space (avoid crowding).
        let barWidthPx = secondsPerBar * pixelsPerSecond
        let labelEvery = max(1, Int(ceil(40.0 / barWidthPx))) // skip labels if bars are < 40px wide

        for bar in 0...totalBars {
            guard bar % labelEvery == 0 else { continue }
            let t = Double(bar) * secondsPerBar
            guard t <= trackDuration else { break }
            let x = t * pixelsPerSecond

            let label = "\(bar + 1)"
            let resolved = context.resolve(Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.45)))
            let textSize = resolved.measure(in: size)

            // Left-align from the tick, but clamp so last label doesn't overflow
            let labelX = min(x + 2, size.width - textSize.width - 2)
            context.draw(resolved, at: CGPoint(x: labelX, y: 4), anchor: .topLeading)
        }

        // --- Playhead needle ---
        guard trackDuration > 0 else { return }
        let headX = (currentTime / trackDuration) * size.width
        var needlePath = Path()
        needlePath.move(to: CGPoint(x: headX, y: 0))
        needlePath.addLine(to: CGPoint(x: headX, y: size.height))
        context.stroke(needlePath, with: .color(.white.opacity(0.85)), lineWidth: 1.5)

        // Small triangle pointer at the top
        var triangle = Path()
        triangle.move(to:    CGPoint(x: headX,     y: 7))
        triangle.addLine(to: CGPoint(x: headX - 4, y: 0))
        triangle.addLine(to: CGPoint(x: headX + 4, y: 0))
        triangle.closeSubpath()
        context.fill(triangle, with: .color(.white.opacity(0.9)))
    }
}

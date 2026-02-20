import SwiftUI

struct WaveformRenderer {
    static func draw(
        context: GraphicsContext,
        size: CGSize,
        samples: [Float],
        playheadPosition: CGFloat,
        loopInPosition: CGFloat,
        loopOutPosition: CGFloat,
        loopEnabled: Bool
    ) {
        guard size.width > 0, size.height > 0 else { return }

        // MARK: - Background
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color(white: 0.08))
        )

        // MARK: - Loop region highlight (only when enabled)
        if loopEnabled && loopOutPosition > loopInPosition {
            let loopX = loopInPosition * size.width
            let loopW = (loopOutPosition - loopInPosition) * size.width
            let loopRect = CGRect(x: loopX, y: 0, width: loopW, height: size.height)
            context.fill(
                Path(loopRect),
                with: .color(Color.blue.opacity(0.18))
            )
        }

        // MARK: - Waveform bars
        guard !samples.isEmpty else { return }

        let barCount = samples.count
        let barWidth = size.width / CGFloat(barCount)
        let centerY = size.height / 2
        let maxBarHeight = size.height * 0.48

        var waveformPath = Path()
        for i in 0..<barCount {
            let amplitude = CGFloat(samples[i])
            let barHeight = max(1.0, amplitude * maxBarHeight)
            let x = CGFloat(i) * barWidth + barWidth * 0.1
            let w = barWidth * 0.8
            let rect = CGRect(
                x: x,
                y: centerY - barHeight,
                width: w,
                height: barHeight * 2
            )
            waveformPath.addRoundedRect(in: rect, cornerSize: CGSize(width: 1, height: 1))
        }

        context.fill(waveformPath, with: .color(Color(red: 0.3, green: 0.75, blue: 0.45)))

        // MARK: - Loop markers (always shown when a region is set, even if disabled)
        if loopOutPosition > loopInPosition {
            drawMarker(context: context, size: size,
                       xPosition: loopInPosition * size.width,
                       isIn: true, enabled: loopEnabled)
            drawMarker(context: context, size: size,
                       xPosition: loopOutPosition * size.width,
                       isIn: false, enabled: loopEnabled)
        }

        // MARK: - Playhead
        let playheadX = playheadPosition * size.width
        var playheadPath = Path()
        playheadPath.move(to: CGPoint(x: playheadX, y: 0))
        playheadPath.addLine(to: CGPoint(x: playheadX, y: size.height))
        context.stroke(
            playheadPath,
            with: .color(.white),
            lineWidth: 2
        )
    }

    // MARK: - Marker drawing

    /// Draws a loop in/out marker: vertical line + downward-pointing triangle cap at the top.
    private static func drawMarker(
        context: GraphicsContext,
        size: CGSize,
        xPosition: CGFloat,
        isIn: Bool,
        enabled: Bool
    ) {
        let color = enabled ? Color(red: 0.35, green: 0.65, blue: 1.0) : Color(white: 0.5)
        let capSize: CGFloat = 10

        // Vertical line
        var linePath = Path()
        linePath.move(to: CGPoint(x: xPosition, y: 0))
        linePath.addLine(to: CGPoint(x: xPosition, y: size.height))
        context.stroke(linePath, with: .color(color), lineWidth: 2)

        // Triangle cap pointing down from the top edge
        // In-marker: cap on the right side of the line
        // Out-marker: cap on the left side of the line
        let tipX = xPosition
        let tipY: CGFloat = capSize
        let baseY: CGFloat = 0
        let baseLeft  = isIn ? xPosition        : xPosition - capSize
        let baseRight = isIn ? xPosition + capSize : xPosition

        var capPath = Path()
        capPath.move(to: CGPoint(x: tipX, y: tipY))
        capPath.addLine(to: CGPoint(x: baseLeft,  y: baseY))
        capPath.addLine(to: CGPoint(x: baseRight, y: baseY))
        capPath.closeSubpath()
        context.fill(capPath, with: .color(color))
    }
}

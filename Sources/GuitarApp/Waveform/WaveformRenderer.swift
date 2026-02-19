import SwiftUI

struct WaveformRenderer {
    static func draw(
        context: GraphicsContext,
        size: CGSize,
        samples: [Float],
        playheadPosition: CGFloat,
        loopInPosition: CGFloat,
        loopOutPosition: CGFloat
    ) {
        guard size.width > 0, size.height > 0 else { return }

        // MARK: - Background
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(Color(white: 0.08))
        )

        // MARK: - Loop region highlight
        if loopOutPosition > loopInPosition {
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
}

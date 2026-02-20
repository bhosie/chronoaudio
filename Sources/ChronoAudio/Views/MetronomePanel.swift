import SwiftUI

/// A compact inline panel that sits in the player controls bar.
/// Shows: metronome on/off toggle, volume slider, and "Detect BPM" button.
struct MetronomePanel: View {
    @ObservedObject var metronomeVM: MetronomeViewModel
    let bpm: Double
    let beatsPerBar: Int
    let beatUnit: Int
    let playbackRate: Float
    /// Called when BPM detection finishes and the user wants to apply the result.
    let onApplyDetectedBPM: (Double) -> Void

    var body: some View {
        HStack(spacing: 12) {

            // Toggle button
            Button {
                metronomeVM.toggle(bpm: bpm, beatsPerBar: beatsPerBar, beatUnit: beatUnit, playbackRate: playbackRate)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "metronome")
                        .font(.system(size: 13, weight: metronomeVM.isRunning ? .semibold : .regular))
                    Text(metronomeVM.isRunning ? "Click: On" : "Click: Off")
                        .font(.system(size: 11, weight: metronomeVM.isRunning ? .semibold : .regular))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(metronomeVM.isRunning
                              ? Color(red: 0.35, green: 0.65, blue: 1.0).opacity(0.20)
                              : Color.white.opacity(0.07))
                )
                .foregroundColor(metronomeVM.isRunning
                                 ? Color(red: 0.35, green: 0.65, blue: 1.0)
                                 : .secondary)
            }
            .buttonStyle(.plain)

            // Volume slider (only visible when on)
            if metronomeVM.isRunning {
                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.1")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Slider(
                        value: Binding(
                            get: { Double(metronomeVM.volume) },
                            set: { metronomeVM.setVolume(Float($0)) }
                        ),
                        in: 0...1
                    )
                    .frame(width: 72)
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }

            // BPM detection
            Button {
                // Will be wired up via onApplyDetectedBPM — detection is
                // triggered from ContentView where the PCM buffer lives.
                onApplyDetectedBPM(-1)   // -1 = "request detect"
            } label: {
                HStack(spacing: 4) {
                    if metronomeVM.isDetecting {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .font(.system(size: 11))
                    }
                    Text(metronomeVM.isDetecting ? "Detecting…" : "Detect BPM")
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.07))
                )
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(metronomeVM.isDetecting)

            // Detected BPM badge + apply button
            if let detected = metronomeVM.detectedBPM {
                HStack(spacing: 4) {
                    Text("→ \(String(format: "%.0f", detected)) BPM")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(red: 0.35, green: 0.65, blue: 1.0))

                    Button("Apply") {
                        onApplyDetectedBPM(detected)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 0.35, green: 0.65, blue: 1.0).opacity(0.20))
                    )
                    .foregroundColor(Color(red: 0.35, green: 0.65, blue: 1.0))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: metronomeVM.isRunning)
        .animation(.easeInOut(duration: 0.15), value: metronomeVM.detectedBPM != nil)
    }
}

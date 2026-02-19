import SwiftUI

struct PlayerControlsView: View {
    @ObservedObject var playerVM: PlayerViewModel
    @Binding var bpm: Double
    @Binding var beatsPerBar: Int

    var body: some View {
        HStack(spacing: 20) {
            // Play / Pause button
            Button {
                if playerVM.isPlaying {
                    playerVM.pause()
                } else {
                    playerVM.play()
                }
            } label: {
                Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(playerVM.track == nil)
            .keyboardShortcut(.space, modifiers: [])

            // Loop toggle button
            Button {
                playerVM.toggleLoop()
            } label: {
                Image(systemName: "repeat")
                    .font(.system(size: 17, weight: isLooping ? .semibold : .regular))
                    .frame(width: 32, height: 32)
                    .foregroundColor(isLooping ? Color(red: 0.35, green: 0.65, blue: 1.0) : .secondary)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isLooping
                                  ? Color(red: 0.35, green: 0.65, blue: 1.0).opacity(0.15)
                                  : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .disabled(playerVM.track == nil)
            .help(isLooping ? "Disable loop" : "Enable loop")

            Divider()
                .frame(height: 28)

            // BPM control
            VStack(alignment: .leading, spacing: 2) {
                Text("BPM")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    Button { bpm = max(40, bpm - 1) } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)

                    TextField("BPM", value: $bpm, format: .number)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .frame(width: 46)
                        .onChange(of: bpm) { newVal in
                            bpm = newVal.clamped(to: 40...300)
                        }

                    Button { bpm = min(300, bpm + 1) } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            .disabled(playerVM.track == nil)

            // Time signature
            VStack(alignment: .leading, spacing: 2) {
                Text("Time Sig")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    // Numerator picker: 2, 3, 4, 5, 6, 7, 8
                    Picker("", selection: $beatsPerBar) {
                        ForEach([2, 3, 4, 5, 6, 7, 8], id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 52)
                    .labelsHidden()

                    Text("/4")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .disabled(playerVM.track == nil)

            Divider()
                .frame(height: 28)

            // Speed slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Speed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(playerVM.playbackState.playbackRate * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { Double(playerVM.playbackState.playbackRate) },
                        set: { playerVM.setPlaybackRate(Float($0)) }
                    ),
                    in: 0.25...1.0,
                    step: 0.05
                )
                .disabled(playerVM.track == nil)
            }
            .frame(maxWidth: 240)

            Spacer()

            // Error message
            if let error = playerVM.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
                    .frame(maxWidth: 200)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.1))
    }

    private var isLooping: Bool {
        playerVM.audioEngine.loopController.isLooping
    }
}

// MARK: - Helpers

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

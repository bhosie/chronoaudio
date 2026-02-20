import SwiftUI

struct PlayerControlsView: View {
    @ObservedObject var playerVM: PlayerViewModel
    @Binding var bpm: Double
    @Binding var beatsPerBar: Int
    @Binding var beatUnit: Int
    @ObservedObject var metronomeVM: MetronomeViewModel
    let onDetectBPM: () -> Void

    /// Local string backing the BPM text field so edits don't fight the binding.
    @State private var bpmText: String = "120"
    @FocusState private var bpmFocused: Bool

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
                HStack(spacing: 6) {
                    Button {
                        let newBPM = (bpm - 1).clamped(to: 40...300)
                        bpm = newBPM
                        bpmText = "\(Int(newBPM))"
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .medium))
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)

                    TextField("", text: $bpmText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .frame(width: 52)
                        .focused($bpmFocused)
                        .onSubmit { commitBPMText() }
                        .onChange(of: bpm) { newBPM in
                            if !bpmFocused {
                                bpmText = "\(Int(newBPM))"
                            }
                        }

                    Button {
                        let newBPM = (bpm + 1).clamped(to: 40...300)
                        bpm = newBPM
                        bpmText = "\(Int(newBPM))"
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .medium))
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
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
                HStack(spacing: 2) {
                    // Numerator: how many beats per bar
                    Picker("", selection: $beatsPerBar) {
                        ForEach([2, 3, 4, 5, 6, 7, 8, 9, 12], id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 52)
                    .labelsHidden()

                    Text("/")
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(.secondary)

                    // Denominator: beat unit (4 = quarter note, 8 = eighth note)
                    Picker("", selection: $beatUnit) {
                        ForEach([4, 8], id: \.self) { d in
                            Text("\(d)").tag(d)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 48)
                    .labelsHidden()
                }
            }
            .disabled(playerVM.track == nil)

            Divider()
                .frame(height: 28)

            // Speed slider + anchor buttons
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Speed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(playerVM.playbackState.playbackRate * 100))%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                }

                Slider(
                    value: Binding(
                        get: { Double(playerVM.playbackState.playbackRate) },
                        set: { playerVM.setPlaybackRate(Float($0)) }
                    ),
                    in: 0.25...1.0,
                    step: 0.05
                )

                // Anchor buttons — tap to snap to a preset, highlight when active
                HStack(spacing: 6) {
                    ForEach([25, 50, 75, 100], id: \.self) { pct in
                        let rate = Float(pct) / 100.0
                        let isActive = abs(playerVM.playbackState.playbackRate - rate) < 0.01
                        Button {
                            playerVM.setPlaybackRate(rate)
                        } label: {
                            Text("\(pct)%")
                                .font(.system(size: 10, weight: isActive ? .semibold : .regular,
                                              design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(isActive
                                              ? Color(red: 0.35, green: 0.65, blue: 1.0).opacity(0.20)
                                              : Color.white.opacity(0.07))
                                )
                                .foregroundColor(isActive
                                                 ? Color(red: 0.35, green: 0.65, blue: 1.0)
                                                 : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
            .disabled(playerVM.track == nil)
            .frame(maxWidth: 240)

            Divider()
                .frame(height: 28)

            // Metronome panel
            MetronomePanel(
                metronomeVM: metronomeVM,
                bpm: bpm,
                beatsPerBar: beatsPerBar,
                beatUnit: beatUnit,
                playbackRate: playerVM.playbackState.playbackRate
            ) { value in
                if value < 0 {
                    onDetectBPM()
                } else {
                    bpm = value
                }
            }
            .disabled(playerVM.track == nil)

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

    /// Parse bpmText → clamp → update bpm binding, re-sync the text field, and drop focus.
    private func commitBPMText() {
        let parsed = Double(bpmText.trimmingCharacters(in: .whitespaces)) ?? bpm
        let clamped = parsed.clamped(to: 40...300)
        bpm = clamped
        bpmText = "\(Int(clamped))"
        bpmFocused = false
    }
}

// MARK: - Helpers

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

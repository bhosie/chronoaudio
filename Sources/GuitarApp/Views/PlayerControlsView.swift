import SwiftUI

struct PlayerControlsView: View {
    @ObservedObject var playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: 24) {
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
            .frame(maxWidth: 260)

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
}

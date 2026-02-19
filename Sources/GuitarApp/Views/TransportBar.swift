import SwiftUI

struct TransportBar: View {
    @ObservedObject var playerVM: PlayerViewModel
    let projectName: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Projects")
                }
                .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            Divider()
                .frame(height: 18)

            // Project name
            Text(projectName)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Time display
            HStack(spacing: 4) {
                Text(TimeFormatter.format(playerVM.playbackState.currentTime))
                    .monospacedDigit()
                Text("/")
                    .foregroundColor(.secondary)
                Text(TimeFormatter.format(playerVM.track?.duration ?? 0))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            .font(.system(size: 13))

            // Loading indicator
            if playerVM.isImporting {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(white: 0.12))
    }
}

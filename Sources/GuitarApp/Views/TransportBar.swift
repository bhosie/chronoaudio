import SwiftUI

struct TransportBar: View {
    @ObservedObject var playerVM: PlayerViewModel
    @Binding var isFileImporterPresented: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Open File button
            Button {
                isFileImporterPresented = true
            } label: {
                Label("Open File", systemImage: "folder.badge.plus")
            }
            .keyboardShortcut("o", modifiers: .command)

            // Track name
            if let track = playerVM.track {
                Text(track.url.deletingPathExtension().lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No file loaded")
                    .foregroundColor(Color.secondary.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

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

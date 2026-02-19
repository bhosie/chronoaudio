import SwiftUI

struct ContentView: View {
    @StateObject private var playerVM = PlayerViewModel()
    @StateObject private var waveformVM = WaveformViewModel()

    @State private var isFileImporterPresented = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: file open + time display
            TransportBar(
                playerVM: playerVM,
                isFileImporterPresented: $isFileImporterPresented
            )

            Divider()

            // Waveform
            WaveformView(waveformVM: waveformVM, playerVM: playerVM)
                .padding(12)

            Divider()

            // Play/pause + speed
            PlayerControlsView(playerVM: playerVM)
        }
        .frame(minWidth: 800, minHeight: 500)
        .preferredColorScheme(.dark)
        .onAppear {
            waveformVM.observe(playerVM)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFileRequested)) { _ in
            isFileImporterPresented = true
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.mp3, .aiff, .wav, .audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                // Need to access the security-scoped resource
                let accessing = url.startAccessingSecurityScopedResource()
                playerVM.importAudio(url: url)
                if accessing {
                    // Keep access open; release after load
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            case .failure(let error):
                playerVM.errorMessage = error.localizedDescription
            }
        }
        .alert("Error", isPresented: Binding(
            get: { playerVM.errorMessage != nil },
            set: { if !$0 { playerVM.errorMessage = nil } }
        )) {
            Button("OK") { playerVM.errorMessage = nil }
        } message: {
            Text(playerVM.errorMessage ?? "")
        }
    }
}

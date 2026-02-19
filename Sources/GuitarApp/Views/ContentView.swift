import SwiftUI

struct ContentView: View {
    let project: Project
    let onBack: (Project) -> Void

    @EnvironmentObject private var projectStore: ProjectStore
    @StateObject private var playerVM = PlayerViewModel()
    @StateObject private var waveformVM = WaveformViewModel()

    @State private var resolvedURL: URL?
    @State private var bookmarkAccessStarted = false
    @State private var restoredState = false

    // Ruler state — persisted to project on back
    @State private var bpm: Double = 120
    @State private var beatsPerBar: Int = 4

    var body: some View {
        VStack(spacing: 0) {
            // Transport bar with back navigation
            TransportBar(
                playerVM: playerVM,
                projectName: project.name,
                onBack: handleBack
            )

            Divider()

            // Bar/beat ruler
            if playerVM.track != nil {
                RulerView(
                    currentTime: playerVM.playbackState.currentTime,
                    trackDuration: playerVM.track?.duration ?? 0,
                    bpm: bpm,
                    beatsPerBar: beatsPerBar
                )
                .padding(.horizontal, 12)
            }

            // Waveform
            WaveformView(waveformVM: waveformVM, playerVM: playerVM)
                .padding(.horizontal, 12)
                .padding(.top, playerVM.track != nil ? 0 : 12)
                .padding(.bottom, 12)

            Divider()

            // Play/pause + loop + BPM + time sig + speed
            PlayerControlsView(
                playerVM: playerVM,
                bpm: $bpm,
                beatsPerBar: $beatsPerBar
            )
        }
        .frame(minWidth: 800, minHeight: 500)
        .preferredColorScheme(.dark)
        .onAppear {
            waveformVM.observe(playerVM)
        }
        .task {
            await restoreProject()
        }
        .onChange(of: playerVM.track) { newTrack in
            // Apply saved state once — on the first publish (fast path, pcmBuffer may be nil).
            // The second publish (buffer filled) must not re-seek or re-apply speed.
            guard newTrack != nil, !restoredState else { return }
            restoredState = true
            applyRestoredState()
        }
        .onDisappear {
            teardown()
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

    // MARK: - Restore

    private func restoreProject() async {
        guard let url = projectStore.resolveURL(for: project) else {
            playerVM.errorMessage = "Audio file not found. The file may have been moved or deleted."
            return
        }
        resolvedURL = url
        bookmarkAccessStarted = url.startAccessingSecurityScopedResource()
        playerVM.importAudio(url: url)
    }

    private func applyRestoredState() {
        playerVM.setPlaybackRate(project.playbackSpeed)
        if project.lastPlayheadPosition > 0 {
            playerVM.seek(to: project.lastPlayheadPosition)
        }
        if let inPt = project.loopInPoint, let outPt = project.loopOutPoint {
            playerVM.setLoopIn(inPt)
            playerVM.setLoopOut(outPt)
            if project.loopEnabled {
                playerVM.enableLoop()
            }
        }
        if let savedBPM = project.bpm { bpm = savedBPM }
        if let savedSig = project.timeSignatureNumerator { beatsPerBar = savedSig }
    }

    // MARK: - Back / Save

    private func handleBack() {
        playerVM.pause()
        let snapshot = playerVM.snapshotProject(from: project, bpm: bpm, beatsPerBar: beatsPerBar)
        teardown()
        onBack(snapshot)
    }

    private func teardown() {
        if bookmarkAccessStarted {
            resolvedURL?.stopAccessingSecurityScopedResource()
            bookmarkAccessStarted = false
        }
    }
}

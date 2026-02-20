import SwiftUI

struct ChronoAudioApp: App {
    @StateObject private var projectStore = ProjectStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(projectStore)
        }
        .commands {
            AppCommands()
        }
    }
}

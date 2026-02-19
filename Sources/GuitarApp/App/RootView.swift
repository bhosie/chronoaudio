import SwiftUI

private enum AppDestination: Equatable {
    case player(Project)

    static func == (lhs: AppDestination, rhs: AppDestination) -> Bool {
        switch (lhs, rhs) {
        case (.player(let a), .player(let b)):
            return a.id == b.id
        }
    }
}

struct RootView: View {
    @EnvironmentObject var projectStore: ProjectStore
    @State private var destination: AppDestination?

    var body: some View {
        Group {
            switch destination {
            case .none:
                HomeView(onOpenProject: { project in
                    destination = .player(project)
                })
                .task {
                    await projectStore.loadProjects()
                }

            case .player(let project):
                ContentView(
                    project: project,
                    onBack: { updatedProject in
                        projectStore.updateProject(updatedProject)
                        destination = nil
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.15), value: destination == nil)
    }
}

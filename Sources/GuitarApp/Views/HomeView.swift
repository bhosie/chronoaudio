import SwiftUI

struct HomeView: View {
    @EnvironmentObject var projectStore: ProjectStore
    let onOpenProject: (Project) -> Void

    @State private var isFileImporterPresented = false
    @State private var editingProjectID: UUID?

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 16)]

    var body: some View {
        ZStack {
            Color(white: 0.08).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("GuitarApp")
                        .font(.largeTitle.bold())
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 20)

                Divider()
                    .opacity(0.3)

                // Grid
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                        NewProjectCard {
                            isFileImporterPresented = true
                        }

                        ForEach(projectStore.projects) { project in
                            ProjectCardView(
                                project: project,
                                isEditing: editingProjectID == project.id,
                                onOpen: {
                                    editingProjectID = nil
                                    onOpenProject(project)
                                },
                                onRename: { newName in
                                    projectStore.renameProject(id: project.id, newName: newName)
                                    editingProjectID = nil
                                },
                                onDelete: {
                                    projectStore.deleteProject(id: project.id)
                                },
                                onBeginRename: {
                                    editingProjectID = project.id
                                }
                            )
                        }
                    }
                    .padding(24)
                }
            }

            // Loading overlay
            if projectStore.isLoading {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView("Loading projects…")
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.mp3, .aiff, .wav, .audio],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert("Error", isPresented: Binding(
            get: { projectStore.errorMessage != nil },
            set: { if !$0 { projectStore.errorMessage = nil } }
        )) {
            Button("OK") { projectStore.errorMessage = nil }
        } message: {
            Text(projectStore.errorMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFileRequested)) { _ in
            isFileImporterPresented = true
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let defaultName = url.deletingPathExtension().lastPathComponent
            guard let project = try? projectStore.createProject(name: defaultName, audioURL: url) else {
                projectStore.errorMessage = "Could not create project for this file."
                return
            }
            onOpenProject(project)
        case .failure(let error):
            projectStore.errorMessage = error.localizedDescription
        }
    }
}

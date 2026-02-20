import Foundation
import Combine

@MainActor
final class ProjectStore: ObservableObject {

    // MARK: - Published State

    @Published private(set) var projects: [Project] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private

    private let fileURL: URL

    // MARK: - Init

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("ChronoAudio", isDirectory: true)
        self.fileURL = dir.appendingPathComponent("projects.json")
    }

    // MARK: - Load

    func loadProjects() async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await readFromDisk(at: fileURL)
            projects = loaded
        } catch {
            if !isFileNotFound(error) {
                errorMessage = "Could not load projects: \(error.localizedDescription)"
            }
            projects = []
        }
        isLoading = false
    }

    // MARK: - Mutations

    @discardableResult
    func createProject(name: String, audioURL: URL) throws -> Project {
        // Attempt a security-scoped bookmark (works in sandboxed .app builds).
        // This will throw or produce a non-functional bookmark when running via
        // `swift run` because entitlements are not applied outside a signed .app.
        // We store it when it succeeds, but always also save the plain path as a
        // reliable fallback for development runs.
        let bookmarkData = try? audioURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let project = Project(
            name: name,
            audioBookmark: bookmarkData,
            audioPath: audioURL.path,
            lastKnownFileName: audioURL.lastPathComponent
        )
        projects.insert(project, at: 0) // newest first
        schedulePersist()
        return project
    }

    func updateProject(_ project: Project) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        var updated = project
        updated.updatedAt = Date()
        projects[idx] = updated
        schedulePersist()
    }

    func renameProject(id: UUID, newName: String) {
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        projects[idx].name = trimmed
        projects[idx].updatedAt = Date()
        schedulePersist()
    }

    func deleteProject(id: UUID) {
        projects.removeAll { $0.id == id }
        schedulePersist()
    }

    // MARK: - Bookmark Resolution

    /// Resolves the audio URL for a project.
    ///
    /// Strategy (in order):
    /// 1. Security-scoped bookmark — correct path for sandboxed `.app` builds.
    /// 2. Plain path fallback (`audioPath`) — used during development when running
    ///    via `swift run`, where entitlements are not applied and security-scoped
    ///    bookmarks cannot be created or resolved.
    ///
    /// Caller is responsible for calling startAccessingSecurityScopedResource()
    /// on the returned URL when it came from a bookmark (check bookmarkAccessStarted).
    func resolveURL(for project: Project) -> URL? {
        // --- Attempt 1: security-scoped bookmark ---
        if let bookmark = project.audioBookmark {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                if isStale {
                    refreshBookmark(for: project, resolvedURL: url)
                }
                return url
            }
        }

        // --- Attempt 2: plain path fallback (non-sandboxed / development) ---
        if let path = project.audioPath {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                return url
            }
        }

        return nil
    }

    // MARK: - Private Helpers

    private func schedulePersist() {
        let snapshot = projects
        let url = fileURL
        Task {
            do {
                try await writeToDisk(snapshot, to: url)
            } catch {
                errorMessage = "Could not save projects: \(error.localizedDescription)"
            }
        }
    }

    private func readFromDisk(at url: URL) async throws -> [Project] {
        let localURL = url
        return try await Task.detached(priority: .utility) {
            let data = try Data(contentsOf: localURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([Project].self, from: data)
        }.value
    }

    private func writeToDisk(_ projects: [Project], to url: URL) async throws {
        let dir = url.deletingLastPathComponent()
        let localURL = url
        try await Task.detached(priority: .utility) {
            let fm = FileManager.default
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(projects)
            try data.write(to: localURL, options: .atomic)
        }.value
    }

    private func isFileNotFound(_ error: Error) -> Bool {
        let code = (error as NSError).code
        return code == NSFileReadNoSuchFileError || code == NSFileNoSuchFileError
    }

    private func refreshBookmark(for project: Project, resolvedURL: URL) {
        guard let fresh = try? resolvedURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[idx].audioBookmark = fresh
        schedulePersist()
    }
}

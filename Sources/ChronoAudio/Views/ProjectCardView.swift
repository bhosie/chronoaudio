import SwiftUI

// MARK: - Project Card

struct ProjectCardView: View {
    let project: Project
    let isEditing: Bool
    let onOpen: () -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let onBeginRename: () -> Void

    @State private var editingName: String = ""
    @State private var isHovered = false
    @State private var isConfirmingDelete = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Card content
            VStack(alignment: .leading, spacing: 8) {
                // Icon area
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 30, weight: .light))
                            .foregroundColor(.accentColor)
                    )
                    .frame(height: 76)

                // Project name
                if isEditing {
                    TextField("Project name", text: $editingName)
                        .textFieldStyle(.plain)
                        .font(.headline)
                        .onSubmit { onRename(editingName) }
                        .onExitCommand { onRename(editingName) }
                        .onAppear { editingName = project.name }
                } else {
                    Text(project.name)
                        .font(.headline)
                        .lineLimit(2)
                        .onTapGesture(count: 2) { onBeginRename() }
                }

                // Metadata
                VStack(alignment: .leading, spacing: 3) {
                    if let fileName = project.lastKnownFileName {
                        Text(fileName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    HStack(spacing: 8) {
                        if project.loopInPoint != nil {
                            Label("Loop", systemImage: "repeat")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if project.playbackSpeed < 0.99 {
                            Text("\(Int(project.playbackSpeed * 100))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if project.lastPlayheadPosition > 1 {
                            Text(TimeFormatter.format(project.lastPlayheadPosition))
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                    }

                    Text(project.updatedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundColor(Color.secondary.opacity(0.6))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(white: isHovered ? 0.18 : 0.14))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isHovered ? Color.white.opacity(0.14) : Color.white.opacity(0.07),
                        lineWidth: 1
                    )
            )

            // Hover-revealed delete button
            if isHovered && !isEditing {
                Button {
                    isConfirmingDelete = true
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.red.opacity(0.85))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(8)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onHover { hovering in isHovered = hovering }
        .onTapGesture {
            guard !isEditing else { return }
            onOpen()
        }
        .contextMenu {
            Button("Rename") { onBeginRename() }
            Divider()
            Button("Delete", role: .destructive) { isConfirmingDelete = true }
        }
        .confirmationDialog(
            "Delete \"\(project.name)\"?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This project will be permanently removed. The audio file will not be deleted.")
        }
    }
}

// MARK: - New Project Card

struct NewProjectCard: View {
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 38))
                .foregroundColor(.accentColor)
            Text("New Project")
                .font(.headline)
            Text("Import an audio file")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color(white: 0.14))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 3])
                )
                .foregroundColor(Color.accentColor.opacity(0.5))
        )
        .onTapGesture { onTap() }
    }
}

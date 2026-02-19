import SwiftUI

extension Notification.Name {
    static let openFileRequested = Notification.Name("com.guitarapp.openFileRequested")
    static let zoomInRequested   = Notification.Name("com.guitarapp.zoomInRequested")
    static let zoomOutRequested  = Notification.Name("com.guitarapp.zoomOutRequested")
    static let zoomResetRequested = Notification.Name("com.guitarapp.zoomResetRequested")
}

struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open…") {
                NotificationCenter.default.post(name: .openFileRequested, object: nil)
            }
            .keyboardShortcut("o", modifiers: .command)
        }

        // Inject zoom commands into the system-provided View menu
        CommandGroup(after: .toolbar) {
            Divider()
            Button("Zoom In") {
                NotificationCenter.default.post(name: .zoomInRequested, object: nil)
            }
            .keyboardShortcut("+", modifiers: .command)

            Button("Zoom Out") {
                NotificationCenter.default.post(name: .zoomOutRequested, object: nil)
            }
            .keyboardShortcut("-", modifiers: .command)

            Button("Reset Zoom") {
                NotificationCenter.default.post(name: .zoomResetRequested, object: nil)
            }
            .keyboardShortcut("0", modifiers: .command)
        }
    }
}

import SwiftUI

extension Notification.Name {
    static let openFileRequested = Notification.Name("com.guitarapp.openFileRequested")
}

struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open…") {
                NotificationCenter.default.post(name: .openFileRequested, object: nil)
            }
            .keyboardShortcut("o", modifiers: .command)
        }
    }
}

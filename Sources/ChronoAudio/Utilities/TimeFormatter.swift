import Foundation

enum TimeFormatter {
    static func format(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%05.2f", mins, secs)
    }
}

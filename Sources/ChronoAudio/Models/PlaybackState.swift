import Foundation

enum PlaybackStatus: Equatable {
    case idle
    case loading
    case playing
    case paused
    case error(Error)

    static func == (lhs: PlaybackStatus, rhs: PlaybackStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.playing, .playing), (.paused, .paused): return true
        case (.error, .error): return true
        default: return false
        }
    }
}

struct PlaybackState {
    var status: PlaybackStatus = .idle
    var currentTime: TimeInterval = 0
    var playbackRate: Float = 1.0
    var loopRegion: LoopRegion?
}

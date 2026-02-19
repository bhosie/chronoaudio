import Foundation

enum PlaybackStatus {
    case idle
    case loading
    case playing
    case paused
    case error(Error)
}

struct PlaybackState {
    var status: PlaybackStatus = .idle
    var currentTime: TimeInterval = 0
    var playbackRate: Float = 1.0
    var loopRegion: LoopRegion?
}

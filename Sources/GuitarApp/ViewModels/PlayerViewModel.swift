import Foundation
import Combine
import SwiftUI

@MainActor
final class PlayerViewModel: ObservableObject {

    @Published var track: AudioTrack?
    @Published var playbackState: PlaybackState = PlaybackState()
    @Published var isImporting: Bool = false
    @Published var errorMessage: String?

    let audioEngine = AudioEngine()

    init() {
        audioEngine.onTimeUpdate = { [weak self] time in
            Task { @MainActor [weak self] in
                self?.playbackState.currentTime = time
            }
        }
        audioEngine.onPlaybackEnded = { [weak self] in
            Task { @MainActor [weak self] in
                self?.playbackState.status = .idle
            }
        }
    }

    func importAudio(url: URL) {
        Task {
            isImporting = true
            errorMessage = nil
            do {
                let loadedTrack = try audioEngine.prepare(with: url)
                track = loadedTrack
                playbackState = PlaybackState()
            } catch {
                errorMessage = error.localizedDescription
            }
            isImporting = false
        }
    }

    func play() {
        guard track != nil else { return }
        audioEngine.play()
        playbackState.status = .playing
    }

    func pause() {
        audioEngine.pause()
        playbackState.status = .paused
    }

    func seek(to time: TimeInterval) {
        audioEngine.seek(to: time)
        playbackState.currentTime = time
    }

    func setPlaybackRate(_ rate: Float) {
        audioEngine.setRate(rate)
        playbackState.playbackRate = rate
    }

    var isPlaying: Bool {
        if case .playing = playbackState.status { return true }
        return false
    }
}

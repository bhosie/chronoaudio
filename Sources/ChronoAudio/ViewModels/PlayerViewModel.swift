import Foundation
import Combine
import SwiftUI
import AVFoundation

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
                // Phase 1 (fast): metadata + engine setup only — no PCM decode.
                // Sets `track` immediately so the player view is interactive right away.
                let loadedTrack = try audioEngine.prepare(with: url)
                track = loadedTrack
                playbackState = PlaybackState()
                isImporting = false

                // Phase 2 (async background): decode full PCM buffer for waveform.
                // Runs on a detached task so it never blocks the main thread.
                let frameCount = loadedTrack.frameCount
                let sampleRate = loadedTrack.sampleRate
                let channelCount = AVAudioChannelCount(loadedTrack.channelCount)
                let pcmBuffer = try await Task.detached(priority: .utility) {
                    try AudioFileLoader().loadPCMBuffer(
                        for: url,
                        frameCount: frameCount,
                        sampleRate: sampleRate,
                        channelCount: channelCount
                    )
                }.value

                // Publish the filled buffer back to the track on the MainActor.
                if track?.url == url {
                    track = AudioTrack(
                        url: loadedTrack.url,
                        duration: loadedTrack.duration,
                        sampleRate: loadedTrack.sampleRate,
                        channelCount: loadedTrack.channelCount,
                        frameCount: loadedTrack.frameCount,
                        pcmBuffer: pcmBuffer
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
                isImporting = false
            }
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

    // MARK: - Loop control

    func setLoopIn(_ time: TimeInterval) {
        guard let track = track else { return }
        let outPoint = playbackState.loopRegion?.outPoint ?? track.duration
        if let region = LoopRegion.validated(inPoint: time, outPoint: outPoint, trackDuration: track.duration) {
            playbackState.loopRegion = region
            if region.isEnabled {
                audioEngine.updateLoopRegion(region)
            }
        }
    }

    func setLoopOut(_ time: TimeInterval) {
        guard let track = track else { return }
        let inPoint = playbackState.loopRegion?.inPoint ?? 0
        if let region = LoopRegion.validated(inPoint: inPoint, outPoint: time, trackDuration: track.duration) {
            playbackState.loopRegion = region
            if region.isEnabled {
                audioEngine.updateLoopRegion(region)
            }
        }
    }

    func enableLoop() {
        guard let track = track else { return }
        // Use existing region or default to full track
        let region = playbackState.loopRegion ?? LoopRegion(
            inPoint: 0,
            outPoint: track.duration,
            isEnabled: true
        )
        let enabled = LoopRegion(inPoint: region.inPoint, outPoint: region.outPoint, isEnabled: true)
        playbackState.loopRegion = enabled
        audioEngine.enableLoop(region: enabled)
    }

    func disableLoop() {
        if var region = playbackState.loopRegion {
            region.isEnabled = false
            playbackState.loopRegion = region
        }
        audioEngine.disableLoop()
    }

    func toggleLoop() {
        if audioEngine.loopController.isLooping {
            disableLoop()
        } else {
            enableLoop()
        }
    }

    // MARK: - Project snapshot

    /// Pure value transform: copies the source Project and fills in current playback state.
    /// No I/O, no side effects. The caller is responsible for persisting the result.
    func snapshotProject(from source: Project, bpm: Double, beatsPerBar: Int, beatUnit: Int) -> Project {
        var updated = source
        updated.lastPlayheadPosition = playbackState.currentTime
        updated.playbackSpeed = playbackState.playbackRate
        if let region = playbackState.loopRegion {
            updated.loopInPoint = region.inPoint
            updated.loopOutPoint = region.outPoint
            updated.loopEnabled = region.isEnabled
        } else {
            updated.loopInPoint = nil
            updated.loopOutPoint = nil
            updated.loopEnabled = false
        }
        updated.bpm = bpm
        updated.timeSignatureNumerator = beatsPerBar
        updated.timeSignatureDenominator = beatUnit
        return updated
    }
}

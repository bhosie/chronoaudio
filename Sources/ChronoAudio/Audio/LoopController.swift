import AVFoundation
import Foundation

/// Manages sample-accurate looping between two points in an audio file.
///
/// Loop markers are always stored and scheduled in **audio-file time** (seconds),
/// never wall-clock time. Changing the playback rate on AVAudioUnitTimePitch
/// has no effect on which frames are looped — the same musical content always
/// plays regardless of speed.
final class LoopController {

    // MARK: - State

    private(set) var region: LoopRegion?
    private(set) var isLooping: Bool = false

    // MARK: - Dependencies (set by AudioEngine after node attachment)

    weak var playerNode: AVAudioPlayerNode?
    weak var audioFile: AVAudioFile?

    /// Serial queue for all scheduling calls — completion handlers arrive on
    /// background threads and must never touch the player node from the main thread.
    private let schedulerQueue = DispatchQueue(
        label: "com.guitarapp.loopcontroller",
        qos: .userInteractive
    )

    // MARK: - Public API

    /// Enable looping between the given region. If the player is already
    /// running the caller is responsible for stopping and restarting it
    /// so the first loop segment is scheduled cleanly.
    func enable(region: LoopRegion, audioFile: AVAudioFile) {
        self.region = region
        self.audioFile = audioFile
        isLooping = true
    }

    /// Disable looping. The current segment continues to play to completion
    /// and no further rescheduling occurs.
    func disable() {
        isLooping = false
        region = nil
    }

    /// Schedule the first loop segment onto the player node. Call this after
    /// stopping the node and before calling `playerNode.play()`.
    func scheduleFirstSegment() {
        schedulerQueue.async { [weak self] in
            self?.scheduleSegment()
        }
    }

    // MARK: - Private scheduling

    private func scheduleSegment() {
        // Bail if loop was disabled while we were queued
        guard isLooping,
              let region = region,
              let playerNode = playerNode,
              let audioFile = audioFile else { return }

        // Frame positions computed from audio-file sample rate only —
        // completely independent of timePitchNode.rate.
        let fileSampleRate = audioFile.fileFormat.sampleRate
        let startFrame = AVAudioFramePosition(region.inPoint * fileSampleRate)
        let frameCount = AVAudioFrameCount((region.outPoint - region.inPoint) * fileSampleRate)

        guard frameCount > 0 else { return }

        playerNode.scheduleSegment(
            audioFile,
            startingFrame: startFrame,
            frameCount: frameCount,
            at: nil,
            completionCallbackType: .dataRendered
        ) { [weak self] _ in
            // Completion handler arrives on a background thread.
            // Recurse on our serial queue to schedule the next loop.
            self?.schedulerQueue.async {
                self?.scheduleSegment()
            }
        }
    }
}

import XCTest
import AVFoundation
@testable import GuitarApp

final class AudioEngineTests: XCTestCase {

    func testSetRateUpdatesTimePitchNode() throws {
        let engine = AudioEngine()
        let url = try TestAudioGenerator.generateSineWave()
        _ = try engine.prepare(with: url)
        engine.setRate(0.5)
        XCTAssertEqual(engine.timePitchNode.rate, 0.5, accuracy: 0.001)
    }

    func testPrepareReturnsCorrectDuration() throws {
        let engine = AudioEngine()
        let url = try TestAudioGenerator.generateSineWave(durationSeconds: 2.0)
        let track = try engine.prepare(with: url)
        XCTAssertEqual(track.duration, 2.0, accuracy: 0.05)
    }

    // MARK: - Seek / currentTime tests

    /// seek() must update currentTime synchronously, before any timer fires.
    func testSeekUpdatesCurrentTimeBeforePlay() throws {
        let engine = AudioEngine()
        let url = try TestAudioGenerator.generateSineWave(durationSeconds: 10.0)
        _ = try engine.prepare(with: url)

        engine.seek(to: 4.0)

        XCTAssertEqual(engine.currentTime, 4.0, accuracy: 0.001,
            "currentTime should equal the seek target immediately after seek()")
    }

    /// Seeking to a negative value must clamp to 0.
    func testSeekToNegativeValueClampsToZero() throws {
        let engine = AudioEngine()
        let url = try TestAudioGenerator.generateSineWave(durationSeconds: 5.0)
        _ = try engine.prepare(with: url)

        engine.seek(to: -3.0)

        XCTAssertEqual(engine.currentTime, 0.0, accuracy: 0.001,
            "seek() with a negative value should clamp currentTime to 0")
    }

    /// Seeking past the end of the track must clamp to the track duration.
    func testSeekBeyondDurationClampsToDuration() throws {
        let engine = AudioEngine()
        let url = try TestAudioGenerator.generateSineWave(durationSeconds: 3.0)
        let track = try engine.prepare(with: url)

        engine.seek(to: 999.0)

        XCTAssertEqual(engine.currentTime, track.duration, accuracy: 0.05,
            "seek() beyond track duration should clamp currentTime to track.duration")
    }

    /// Multiple sequential seeks should each update currentTime independently.
    func testMultipleSequentialSeeks() throws {
        let engine = AudioEngine()
        let url = try TestAudioGenerator.generateSineWave(durationSeconds: 10.0)
        _ = try engine.prepare(with: url)

        engine.seek(to: 2.0)
        XCTAssertEqual(engine.currentTime, 2.0, accuracy: 0.001, "After first seek to 2.0")

        engine.seek(to: 7.5)
        XCTAssertEqual(engine.currentTime, 7.5, accuracy: 0.001, "After second seek to 7.5")

        engine.seek(to: 1.0)
        XCTAssertEqual(engine.currentTime, 1.0, accuracy: 0.001, "After third seek backward to 1.0")
    }

    /// seek(to:) when the engine is not playing must still update currentTime
    /// so that resuming playback starts from the correct offset.
    func testSeekWhilePausedPreservesPosition() throws {
        let engine = AudioEngine()
        let url = try TestAudioGenerator.generateSineWave(durationSeconds: 8.0)
        _ = try engine.prepare(with: url)

        // Engine is prepared but not playing — simulates a paused/idle state.
        engine.seek(to: 5.0)

        XCTAssertEqual(engine.currentTime, 5.0, accuracy: 0.001,
            "Seeking while paused should still set currentTime to the target")
    }

    /// pause() must not reset currentTime to 0 — the position should survive
    /// a pause/resume cycle without drifting.
    func testPausePreservesCurrentTime() throws {
        let engine = AudioEngine()
        let url = try TestAudioGenerator.generateSineWave(durationSeconds: 10.0)
        _ = try engine.prepare(with: url)

        engine.seek(to: 3.0)
        // pause() calls computeCurrentTime(); when the node isn't actively
        // rendering (headless test environment), it falls back to _currentTime.
        engine.pause()

        XCTAssertEqual(engine.currentTime, 3.0, accuracy: 0.001,
            "pause() must not reset currentTime — it should retain the seek position")
    }

    /// setRate() must always keep pitch at 0 regardless of the rate value,
    /// to prevent the time-pitch node from altering pitch with speed.
    func testSetRateAlwaysKeepsPitchAtZero() throws {
        let engine = AudioEngine()
        let url = try TestAudioGenerator.generateSineWave()
        _ = try engine.prepare(with: url)

        for rate: Float in [0.25, 0.5, 0.75, 1.0] {
            engine.setRate(rate)
            XCTAssertEqual(engine.timePitchNode.pitch, 0.0, accuracy: 0.001,
                "pitch must be 0.0 when rate is \(rate)")
        }
    }

    /// setRate() should clamp values below 0.25 to 0.25.
    func testSetRateClampsBelow() throws {
        let engine = AudioEngine()
        let url = try TestAudioGenerator.generateSineWave()
        _ = try engine.prepare(with: url)

        engine.setRate(0.1)
        XCTAssertEqual(engine.timePitchNode.rate, 0.25, accuracy: 0.001,
            "rate below 0.25 should be clamped to 0.25")
    }

    /// setRate() should clamp values above 1.0 to 1.0.
    func testSetRateClampsAbove() throws {
        let engine = AudioEngine()
        let url = try TestAudioGenerator.generateSineWave()
        _ = try engine.prepare(with: url)

        engine.setRate(2.0)
        XCTAssertEqual(engine.timePitchNode.rate, 1.0, accuracy: 0.001,
            "rate above 1.0 should be clamped to 1.0")
    }
}

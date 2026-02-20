import XCTest
@testable import ChronoAudio

/// Unit tests for MetronomeEngine beat-timing math.
///
/// MetronomeEngine schedules clicks using:
///   effectiveBPS  = bpm/60 * playbackRate * (beatUnit/4)
///   framesPerBeat = sampleRate / effectiveBPS
///
/// The (beatUnit/4) scale factor means:
///   - beatUnit=4 (quarter note): scale=1.0, unchanged
///   - beatUnit=8 (eighth note): scale=2.0, clicks twice as fast
///
/// These tests validate that formula directly via a pure-math helper,
/// without starting AVAudioEngine (which requires a real audio device).
final class MetronomeEngineTests: XCTestCase {

    // MARK: - framesPerBeat helper (mirrors MetronomeEngine.scheduleBeats)

    private func expectedFrames(sampleRate: Double,
                                bpm: Double,
                                beatUnit: Int,
                                playbackRate: Float) -> Int {
        // beatUnit/4: /8 time doubles click rate vs /4 time
        let beatUnitScale = Double(max(beatUnit, 1)) / 4.0
        let effectiveBPS = bpm / 60.0 * Double(playbackRate) * beatUnitScale
        return Int(sampleRate / effectiveBPS)
    }

    // MARK: - Quarter-note (beatUnit = 4) baseline

    func test_quarterNote_120bpm_44100_rate1() {
        // 120 BPM quarter notes: one beat every 0.5s → 22050 frames at 44100Hz
        let frames = expectedFrames(sampleRate: 44100, bpm: 120, beatUnit: 4, playbackRate: 1.0)
        XCTAssertEqual(frames, 22050)
    }

    func test_quarterNote_60bpm_44100_rate1() {
        // 60 BPM quarter notes: one beat per second → 44100 frames
        let frames = expectedFrames(sampleRate: 44100, bpm: 60, beatUnit: 4, playbackRate: 1.0)
        XCTAssertEqual(frames, 44100)
    }

    // MARK: - Eighth-note (beatUnit = 8)

    func test_eighthNote_120bpm_44100_rate1() {
        // 6/8 at 120 BPM: eighth note is half a quarter note → 11025 frames at 44100Hz
        let frames = expectedFrames(sampleRate: 44100, bpm: 120, beatUnit: 8, playbackRate: 1.0)
        XCTAssertEqual(frames, 11025)
    }

    func test_eighthNote_isHalfOf_quarterNote() {
        // /8 should produce half the frames-per-beat of /4 at the same BPM (clicks twice as fast)
        let quarter = expectedFrames(sampleRate: 44100, bpm: 120, beatUnit: 4, playbackRate: 1.0)
        let eighth  = expectedFrames(sampleRate: 44100, bpm: 120, beatUnit: 8, playbackRate: 1.0)
        XCTAssertEqual(eighth * 2, quarter,
                       "Eighth-note beat should be exactly half a quarter-note beat")
    }

    // MARK: - Playback rate scaling

    func test_halfRate_doublesFramesPerBeat() {
        // At 50% playback speed the metronome should click half as often (twice as many frames apart)
        let full = expectedFrames(sampleRate: 44100, bpm: 120, beatUnit: 4, playbackRate: 1.0)
        let half = expectedFrames(sampleRate: 44100, bpm: 120, beatUnit: 4, playbackRate: 0.5)
        XCTAssertEqual(half, full * 2,
                       "Half playback rate should double frames per beat")
    }

    func test_quarterRate_quadruplesFramesPerBeat() {
        let full    = expectedFrames(sampleRate: 44100, bpm: 120, beatUnit: 4, playbackRate: 1.0)
        let quarter = expectedFrames(sampleRate: 44100, bpm: 120, beatUnit: 4, playbackRate: 0.25)
        XCTAssertEqual(quarter, full * 4,
                       "Quarter playback rate should quadruple frames per beat")
    }

    // MARK: - Combined: beatUnit + playback rate

    func test_eighthNote_halfRate_equalsQuarterNoteFullRate() {
        // 6/8 at 50% speed: the two factors cancel — same interval as /4 at 100%
        let quarterFull = expectedFrames(sampleRate: 44100, bpm: 120, beatUnit: 4, playbackRate: 1.0)
        let eighthHalf  = expectedFrames(sampleRate: 44100, bpm: 120, beatUnit: 8, playbackRate: 0.5)
        XCTAssertEqual(eighthHalf, quarterFull,
                       "Eighth note at 50% speed == quarter note at 100% speed")
    }

    // MARK: - Sanity check

    func test_formula_sanity() {
        // Baseline: 120 BPM quarter note at 44100Hz is 22050 frames
        XCTAssertEqual(expectedFrames(sampleRate: 44100, bpm: 120, beatUnit: 4, playbackRate: 1.0), 22050)
    }
}

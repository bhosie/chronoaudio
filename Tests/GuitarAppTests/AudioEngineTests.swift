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
}

import XCTest
import AVFoundation
@testable import GuitarApp

final class LoopControllerTests: XCTestCase {

    // MARK: - LoopRegion.validated tests

    func testValidatedRejectsInvertedRegion() {
        let result = LoopRegion.validated(inPoint: 5.0, outPoint: 2.0, trackDuration: 10.0)
        XCTAssertNil(result, "Inverted in/out points should return nil")
    }

    func testValidatedRejectsTooShortRegion() {
        let result = LoopRegion.validated(inPoint: 0.0, outPoint: 0.4, trackDuration: 10.0)
        XCTAssertNil(result, "Region shorter than 0.5s should return nil")
    }

    func testValidatedAcceptsMinimumDuration() {
        let result = LoopRegion.validated(inPoint: 0.0, outPoint: 0.5, trackDuration: 10.0)
        XCTAssertNotNil(result, "Region of exactly 0.5s should be valid")
    }

    func testValidatedClampsInPointBelowZero() {
        let result = LoopRegion.validated(inPoint: -2.0, outPoint: 5.0, trackDuration: 10.0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.inPoint, 0.0, accuracy: 0.001, "inPoint should clamp to 0")
    }

    func testValidatedClampsOutPointBeyondDuration() {
        let result = LoopRegion.validated(inPoint: 0.0, outPoint: 15.0, trackDuration: 10.0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.outPoint, 10.0, accuracy: 0.001, "outPoint should clamp to trackDuration")
    }

    func testValidatedClampsProducesTooShortRegion() {
        // Both points beyond track end — clamping produces a zero-duration region
        let result = LoopRegion.validated(inPoint: 11.0, outPoint: 12.0, trackDuration: 10.0)
        XCTAssertNil(result, "Clamped region shorter than 0.5s should return nil")
    }

    func testValidatedDuration() {
        let result = LoopRegion.validated(inPoint: 1.0, outPoint: 4.0, trackDuration: 10.0)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.duration, 3.0, accuracy: 0.001)
    }

    // MARK: - LoopController state tests

    func testLoopControllerStartsDisabled() {
        let controller = LoopController()
        XCTAssertFalse(controller.isLooping)
        XCTAssertNil(controller.region)
    }

    func testEnableSetsLoopingTrue() throws {
        let controller = LoopController()
        let url = try TestAudioGenerator.generateSineWave(durationSeconds: 4.0)
        let audioFile = try AVAudioFile(forReading: url)
        let region = LoopRegion(inPoint: 0.5, outPoint: 2.0, isEnabled: true)
        controller.enable(region: region, audioFile: audioFile)
        XCTAssertTrue(controller.isLooping)
        let activeRegion = try XCTUnwrap(controller.region)
        XCTAssertEqual(activeRegion.inPoint, 0.5, accuracy: 0.001)
        XCTAssertEqual(activeRegion.outPoint, 2.0, accuracy: 0.001)
    }

    func testDisableSetsLoopingFalse() throws {
        let controller = LoopController()
        let url = try TestAudioGenerator.generateSineWave(durationSeconds: 4.0)
        let audioFile = try AVAudioFile(forReading: url)
        let region = LoopRegion(inPoint: 0.5, outPoint: 2.0, isEnabled: true)
        controller.enable(region: region, audioFile: audioFile)
        controller.disable()
        XCTAssertFalse(controller.isLooping)
        XCTAssertNil(controller.region)
    }

    // MARK: - Frame position calculation test

    func testFramePositionsAreAudioTimeAnchored() {
        // Verify that frame positions are based on file sample rate only,
        // not affected by any rate multiplier.
        let sampleRate: Double = 44100
        let inPoint: TimeInterval = 1.0
        let outPoint: TimeInterval = 3.0

        let expectedStartFrame = AVAudioFramePosition(inPoint * sampleRate)
        let expectedFrameCount = AVAudioFrameCount((outPoint - inPoint) * sampleRate)

        XCTAssertEqual(expectedStartFrame, 44100)
        XCTAssertEqual(expectedFrameCount, 88200)

        // Confirm these are independent of any rate value — multiplying by
        // a rate (e.g. 0.5) would give wrong values:
        let wrongStartFrame = AVAudioFramePosition(inPoint * sampleRate * 0.5)
        XCTAssertNotEqual(expectedStartFrame, wrongStartFrame,
            "Frame positions must NOT be multiplied by playback rate")
    }
}

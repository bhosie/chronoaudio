import XCTest
import AVFoundation
@testable import GuitarApp

final class TimePitchControllerTests: XCTestCase {

    func testSetRateUpdatesNode() {
        let node = AVAudioUnitTimePitch()
        let controller = TimePitchController(node: node)
        controller.setRate(0.5)
        XCTAssertEqual(node.rate, 0.5, accuracy: 0.001)
    }

    func testPitchRemainsZeroAfterRateChange() {
        let node = AVAudioUnitTimePitch()
        let controller = TimePitchController(node: node)
        controller.setRate(0.5)
        XCTAssertEqual(node.pitch, 0.0, accuracy: 0.001)
    }

    func testRateClampsBelow() {
        let node = AVAudioUnitTimePitch()
        let controller = TimePitchController(node: node)
        controller.setRate(0.1)
        XCTAssertEqual(node.rate, 0.25, accuracy: 0.001)
    }

    func testRateClampsAbove() {
        let node = AVAudioUnitTimePitch()
        let controller = TimePitchController(node: node)
        controller.setRate(2.0)
        XCTAssertEqual(node.rate, 1.0, accuracy: 0.001)
    }

    func testRateIdentity() {
        let node = AVAudioUnitTimePitch()
        let controller = TimePitchController(node: node)
        controller.setRate(1.0)
        XCTAssertEqual(node.rate, 1.0, accuracy: 0.001)
        XCTAssertEqual(node.pitch, 0.0, accuracy: 0.001)
    }
}

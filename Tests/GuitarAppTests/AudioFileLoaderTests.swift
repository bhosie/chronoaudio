import XCTest
import AVFoundation
@testable import GuitarApp

final class AudioFileLoaderTests: XCTestCase {

    func testLoadValidAIFF() throws {
        let url = try TestAudioGenerator.generateSineWave(
            frequency: 440,
            sampleRate: 44100,
            durationSeconds: 1.0
        )
        let loader = AudioFileLoader()
        let (track, _) = try loader.load(url: url)
        XCTAssertEqual(track.sampleRate, 44100, accuracy: 1)
        XCTAssertEqual(track.duration, 1.0, accuracy: 0.01)
        XCTAssertEqual(track.channelCount, 1)
        XCTAssertNotNil(track.pcmBuffer)
    }

    func testLoadNonAudioFileThrows() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
        try? "hello".write(to: url, atomically: true, encoding: .utf8)
        let loader = AudioFileLoader()
        XCTAssertThrowsError(try loader.load(url: url))
    }
}

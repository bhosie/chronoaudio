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
        // Fast-path load returns nil pcmBuffer — waveform is loaded separately
        XCTAssertNil(track.pcmBuffer, "Fast-path load should not decode PCM buffer")
    }

    func testLoadPCMBufferDecodesAudio() throws {
        let url = try TestAudioGenerator.generateSineWave(
            frequency: 440,
            sampleRate: 44100,
            durationSeconds: 1.0
        )
        let loader = AudioFileLoader()
        let (track, _) = try loader.load(url: url)
        let buffer = try loader.loadPCMBuffer(
            for: url,
            frameCount: track.frameCount,
            sampleRate: track.sampleRate,
            channelCount: AVAudioChannelCount(track.channelCount)
        )
        XCTAssertEqual(buffer.frameLength, track.frameCount)
        XCTAssertNotNil(buffer.floatChannelData)
    }

    func testLoadNonAudioFileThrows() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
        try? "hello".write(to: url, atomically: true, encoding: .utf8)
        let loader = AudioFileLoader()
        XCTAssertThrowsError(try loader.load(url: url))
    }
}

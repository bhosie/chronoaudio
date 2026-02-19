import XCTest
import AVFoundation
@testable import GuitarApp

final class WaveformSamplerTests: XCTestCase {

    private let sampler = WaveformSampler()

    // MARK: - Helpers

    private func makeSilentBuffer(frameCount: Int, channels: Int = 1, sampleRate: Double = 44100) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: AVAudioChannelCount(channels), interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
        buffer.frameLength = AVAudioFrameCount(frameCount)
        return buffer
    }

    private func makeFullAmplitudeSineBuffer(frameCount: Int = 44100, sampleRate: Double = 44100) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
        buffer.frameLength = AVAudioFrameCount(frameCount)
        let data = buffer.floatChannelData![0]
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            data[i] = Float(sin(2.0 * Double.pi * 440.0 * t))
        }
        return buffer
    }

    private func makeStereoBuffer(frameCount: Int = 44100, sampleRate: Double = 44100) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 2, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
        buffer.frameLength = AVAudioFrameCount(frameCount)
        let ch0 = buffer.floatChannelData![0]
        let ch1 = buffer.floatChannelData![1]
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            ch0[i] = Float(sin(2.0 * Double.pi * 440.0 * t))
            ch1[i] = Float(sin(2.0 * Double.pi * 440.0 * t))
        }
        return buffer
    }

    // MARK: - Tests

    func testOutputCountMatchesTargetCount() async {
        let buffer = makeFullAmplitudeSineBuffer()
        let result = await sampler.sample(buffer: buffer, targetCount: 512)
        XCTAssertEqual(result.count, 512)
    }

    func testOutputCountMatchesTargetCountSmall() async {
        let buffer = makeFullAmplitudeSineBuffer()
        let result = await sampler.sample(buffer: buffer, targetCount: 100)
        XCTAssertEqual(result.count, 100)
    }

    func testAllValuesInZeroToOneRange() async {
        let buffer = makeFullAmplitudeSineBuffer()
        let result = await sampler.sample(buffer: buffer, targetCount: 256)
        for val in result {
            XCTAssertGreaterThanOrEqual(val, 0.0, "Value \(val) is below 0")
            XCTAssertLessThanOrEqual(val, 1.0, "Value \(val) exceeds 1")
        }
    }

    func testSilentBufferReturnsAllZeros() async {
        let buffer = makeSilentBuffer(frameCount: 44100)
        let result = await sampler.sample(buffer: buffer, targetCount: 256)
        XCTAssertEqual(result.count, 256)
        for val in result {
            XCTAssertEqual(val, 0.0, accuracy: 1e-6, "Silent buffer should produce zeros")
        }
    }

    func testFullAmplitudeSineReturnsNearOne() async {
        let buffer = makeFullAmplitudeSineBuffer(frameCount: 44100)
        let result = await sampler.sample(buffer: buffer, targetCount: 256)
        let maxVal = result.max() ?? 0
        XCTAssertEqual(maxVal, 1.0, accuracy: 0.01, "Full-amplitude sine should normalize to max ~1.0")
    }

    func testMonoBufferProducesCorrectCount() async {
        let buffer = makeSilentBuffer(frameCount: 22050, channels: 1)
        let result = await sampler.sample(buffer: buffer, targetCount: 128)
        XCTAssertEqual(result.count, 128)
    }

    func testStereoBufferProducesCorrectCount() async {
        let buffer = makeStereoBuffer(frameCount: 44100)
        let result = await sampler.sample(buffer: buffer, targetCount: 256)
        XCTAssertEqual(result.count, 256)
    }

    func testStereoBufferValuesInRange() async {
        let buffer = makeStereoBuffer(frameCount: 44100)
        let result = await sampler.sample(buffer: buffer, targetCount: 256)
        for val in result {
            XCTAssertGreaterThanOrEqual(val, 0.0)
            XCTAssertLessThanOrEqual(val, 1.0)
        }
    }

    func testZeroTargetCountReturnsEmpty() async {
        let buffer = makeFullAmplitudeSineBuffer()
        let result = await sampler.sample(buffer: buffer, targetCount: 0)
        XCTAssertTrue(result.isEmpty)
    }
}

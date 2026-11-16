import XCTest
@testable import ChronoAudio

@MainActor
final class PlayerViewModelTests: XCTestCase {

    private func makeLoadedViewModel(durationSeconds: Double = 10.0) throws -> PlayerViewModel {
        let vm = PlayerViewModel()
        let url = try TestAudioGenerator.generateSineWave(durationSeconds: durationSeconds)
        let track = try vm.audioEngine.prepare(with: url)
        vm.track = track
        return vm
    }

    /// With looping off, back-to-start must return to the very beginning of the song.
    func testBackToStartWithoutLoopGoesToZero() throws {
        let vm = try makeLoadedViewModel()
        vm.seek(to: 6.0)

        vm.backToStart()

        XCTAssertEqual(vm.playbackState.currentTime, 0.0, accuracy: 0.001)
        XCTAssertEqual(vm.audioEngine.currentTime, 0.0, accuracy: 0.001)
    }

    /// With looping on, back-to-start must return to the loop's in-point, not 0.
    func testBackToStartWithLoopGoesToLoopInPoint() throws {
        let vm = try makeLoadedViewModel()
        vm.setLoopIn(3.0)
        vm.setLoopOut(7.0)
        vm.enableLoop()
        vm.seek(to: 5.0)

        vm.backToStart()

        XCTAssertEqual(vm.playbackState.currentTime, 3.0, accuracy: 0.001)
        XCTAssertEqual(vm.audioEngine.currentTime, 3.0, accuracy: 0.001)
    }

    /// Disabling the loop after it was used must restore the plain "start of song" behavior.
    func testBackToStartAfterDisablingLoopGoesToZero() throws {
        let vm = try makeLoadedViewModel()
        vm.setLoopIn(3.0)
        vm.setLoopOut(7.0)
        vm.enableLoop()
        vm.disableLoop()
        vm.seek(to: 5.0)

        vm.backToStart()

        XCTAssertEqual(vm.playbackState.currentTime, 0.0, accuracy: 0.001)
    }

    /// No-op when no track is loaded — must not crash.
    func testBackToStartWithNoTrackIsNoOp() {
        let vm = PlayerViewModel()
        vm.backToStart()
        XCTAssertEqual(vm.playbackState.currentTime, 0.0, accuracy: 0.001)
    }
}

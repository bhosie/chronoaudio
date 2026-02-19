import Foundation
import Combine

@MainActor
final class WaveformViewModel: ObservableObject {
    @Published var waveformSamples: [Float] = []
    @Published var playheadPosition: CGFloat = 0
    @Published var loopInPosition: CGFloat = 0
    @Published var loopOutPosition: CGFloat = 1
}

import Foundation
import Combine

@MainActor
final class MetronomeViewModel: ObservableObject {
    @Published var config: MetronomeConfig = MetronomeConfig()
    @Published var detectedBPM: Double?
    @Published var isBeatDetecting: Bool = false
}

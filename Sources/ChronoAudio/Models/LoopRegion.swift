import Foundation

struct LoopRegion {
    var inPoint: TimeInterval
    var outPoint: TimeInterval
    var isEnabled: Bool

    var duration: TimeInterval { outPoint - inPoint }

    static func validated(
        inPoint: TimeInterval,
        outPoint: TimeInterval,
        trackDuration: TimeInterval
    ) -> LoopRegion? {
        let clampedIn = max(0, min(inPoint, trackDuration))
        let clampedOut = max(0, min(outPoint, trackDuration))
        guard clampedOut - clampedIn >= 0.5 else { return nil }
        return LoopRegion(inPoint: clampedIn, outPoint: clampedOut, isEnabled: true)
    }
}

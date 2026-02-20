import Foundation

struct Project: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String                        // user-editable; defaults to filename stem
    var createdAt: Date
    var updatedAt: Date

    // Audio file reference.
    // audioBookmark: security-scoped bookmark — used in sandboxed (.app) builds.
    // audioPath: plain POSIX path — fallback for development (swift run, no sandbox).
    // resolveURL() tries the bookmark first, then falls back to the plain path.
    var audioBookmark: Data?
    var audioPath: String?                  // plain path fallback for non-sandboxed runs
    var lastKnownFileName: String?          // display fallback when bookmark is stale

    // Playback state to restore
    var loopInPoint: TimeInterval?          // nil = no loop region saved
    var loopOutPoint: TimeInterval?
    var loopEnabled: Bool
    var playbackSpeed: Float                // 0.25...1.0
    var lastPlayheadPosition: TimeInterval

    // Ruler / tempo (nil = user hasn't set one; UI shows a default)
    var bpm: Double?
    var timeSignatureNumerator: Int?
    var timeSignatureDenominator: Int?      // beat unit: 4 = quarter note, 8 = eighth note

    // MARK: - Init

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        audioBookmark: Data? = nil,
        audioPath: String? = nil,
        lastKnownFileName: String? = nil,
        loopInPoint: TimeInterval? = nil,
        loopOutPoint: TimeInterval? = nil,
        loopEnabled: Bool = false,
        playbackSpeed: Float = 1.0,
        lastPlayheadPosition: TimeInterval = 0,
        bpm: Double? = nil,
        timeSignatureNumerator: Int? = nil,
        timeSignatureDenominator: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.audioBookmark = audioBookmark
        self.audioPath = audioPath
        self.lastKnownFileName = lastKnownFileName
        self.loopInPoint = loopInPoint
        self.loopOutPoint = loopOutPoint
        self.loopEnabled = loopEnabled
        self.playbackSpeed = playbackSpeed
        self.lastPlayheadPosition = lastPlayheadPosition
        self.bpm = bpm
        self.timeSignatureNumerator = timeSignatureNumerator
        self.timeSignatureDenominator = timeSignatureDenominator
    }

    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }
}

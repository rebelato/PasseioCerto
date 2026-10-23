import Foundation

public struct PlayerPreferences: Codable, Equatable, Sendable {
    public var dogName = "Margot"
    public static let nameLimit = 24
    public static func normalizedName(_ value: String) -> String {
        let words = value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        let clean = String(words.unicodeScalars.filter { $0.value >= 32 && $0.value != 127 })
        return clean.isEmpty ? "Margot" : String(clean.prefix(nameLimit))
    }
    public var marking = false
    public var soundEnabled = true
    public var hapticsEnabled = true
    /// Mode for the next normal walk; daily challenges are always Tranquilo.
    public var playMode = PlayMode.relaxed
    public init() {}
    private enum CodingKeys: String, CodingKey { case dogName, marking, soundEnabled, hapticsEnabled, playMode }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dogName = Self.normalizedName(try c.decodeIfPresent(String.self, forKey: .dogName) ?? "Margot")
        marking = try c.decode(Bool.self, forKey: .marking)
        soundEnabled = try c.decode(Bool.self, forKey: .soundEnabled)
        hapticsEnabled = try c.decode(Bool.self, forKey: .hapticsEnabled)
        playMode = try c.decodeIfPresent(PlayMode.self, forKey: .playMode) ?? .relaxed
    }
}
public struct PlayerSave: Codable, Sendable {
    public let schemaVersion: Int
    public var attempt: GameAttempt
    public var preferences: PlayerPreferences
    public var tutorialStep: Int
    public var completedPuzzleIDs: Set<String>
    public var activeDailyID: String?
    public var parkedAttempts: [String: GameAttempt]
    /// Best paw score per completed puzzle (1–3).
    public var bestPaws: [String: Int]
    public init(attempt: GameAttempt = GameAttempt(), preferences: PlayerPreferences = PlayerPreferences(), tutorialStep: Int = 0, completedPuzzleIDs: Set<String> = [], activeDailyID: String? = nil, parkedAttempts: [String: GameAttempt] = [:], bestPaws: [String: Int] = [:]) {
        schemaVersion = 5; self.bestPaws = bestPaws; self.activeDailyID = activeDailyID; self.parkedAttempts = parkedAttempts; self.attempt = attempt; self.preferences = preferences
        self.tutorialStep = tutorialStep; self.completedPuzzleIDs = completedPuzzleIDs
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, attempt, preferences, tutorialStep, completedPuzzleIDs, activeDailyID, parkedAttempts, bestPaws }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.attempt) {
            let version = try c.decode(Int.self, forKey: .schemaVersion)
            schemaVersion = 5
            guard (3...5).contains(version) else { throw PuzzleError.invalidSession }
            attempt = try c.decode(GameAttempt.self, forKey: .attempt)
            preferences = try c.decode(PlayerPreferences.self, forKey: .preferences)
            tutorialStep = try c.decode(Int.self, forKey: .tutorialStep)
            completedPuzzleIDs = try c.decode(Set<String>.self, forKey: .completedPuzzleIDs)
            activeDailyID = version >= 4 ? try c.decodeIfPresent(String.self, forKey: .activeDailyID) : nil
            parkedAttempts = version >= 4 ? try c.decode([String: GameAttempt].self, forKey: .parkedAttempts) : [:]
            guard parkedAttempts.allSatisfy({ $0.key == "normal" || ($0.key.hasPrefix("daily-v1-") && $0.value.game.puzzle.puzzleID == $0.key) }),
                  activeDailyID == nil || (activeDailyID == attempt.game.puzzle.puzzleID && activeDailyID!.hasPrefix("daily-v1-") && parkedAttempts["normal"] != nil) else { throw PuzzleError.invalidSession }
            // Walks finished before scores existed count as one paw.
            bestPaws = version == 5 ? try c.decode([String: Int].self, forKey: .bestPaws)
                : Dictionary(uniqueKeysWithValues: completedPuzzleIDs.map { ($0, 1) })
            guard tutorialStep >= 0, completedPuzzleIDs.allSatisfy({ !$0.isEmpty }),
                  bestPaws.values.allSatisfy((1...GameAttempt.maxLives).contains) else { throw PuzzleError.invalidSession }
        } else {
            schemaVersion = 5; bestPaws = [:]; activeDailyID = nil; parkedAttempts = [:]; attempt = try GameAttempt(from: decoder)
            preferences = PlayerPreferences(); tutorialStep = 0; completedPuzzleIDs = []
        }
        if attempt.game.won {
            let id = attempt.game.puzzle.puzzleID
            completedPuzzleIDs.insert(id)
            bestPaws[id] = max(bestPaws[id] ?? 0, attempt.paws)
        }
    }
}

/// One atomic current file plus the last valid snapshot. Unreadable data is never
/// replaced by normal save; recovery must explicitly archive it first.
public struct SaveStore {
    public let url: URL
    public var backupURL: URL { url.appendingPathExtension("backup") }
    private let write: (Data, URL) throws -> Void
    public init(url: URL, write: @escaping (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }) {
        self.url = url; self.write = write
    }
    public func load() throws -> PlayerSave { try decode(url) }
    public func loadBackup() throws -> PlayerSave { try decode(backupURL) }
    private func decode(_ location: URL) throws -> PlayerSave {
        try JSONDecoder().decode(PlayerSave.self, from: Data(contentsOf: location))
    }
    public func save(_ value: PlayerSave) throws {
        let data = try JSONEncoder().encode(value)
        _ = try JSONDecoder().decode(PlayerSave.self, from: data)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            let old = try Data(contentsOf: url)
            _ = try JSONDecoder().decode(PlayerSave.self, from: old)
            try write(old, backupURL)
        }
        try write(data, url)
    }
    /// Explicit recovery preserves the original at a unique sibling path.
    public func recover(_ value: PlayerSave) throws {
        let data = try JSONEncoder().encode(value)
        _ = try JSONDecoder().decode(PlayerSave.self, from: data)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            let archive = url.appendingPathExtension("preserved-\(UUID().uuidString)")
            try FileManager.default.copyItem(at: url, to: archive)
        }
        try write(data, url)
    }
}

import Foundation

/// Mistakes are outside Game's undo history. Defeat and score are derived, never separately mutable.
/// Every walk has three lives, the daily challenge included.
public struct GameAttempt: Codable, Sendable {
    public static let maxLives = 3
    public let schemaVersion: Int
    public internal(set) var game: Game
    public internal(set) var mistakes: Int
    /// The difficulty this walk was made for; nil for daily and older free walks.
    public let difficulty: Difficulty?
    public var lives: Int { max(0, Self.maxLives - mistakes) }
    public var defeated: Bool { lives == 0 }
    /// Score shown as paw prints: 3 for a clean walk, never below 1 once home.
    public var paws: Int { max(1, Self.maxLives - mistakes) }
    public init(game: Game = Game(), difficulty: Difficulty? = nil) {
        schemaVersion = 4; self.game = game; self.difficulty = difficulty; mistakes = 0
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, game, lives, mistakes, difficulty }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.game) {
            let version = try c.decode(Int.self, forKey: .schemaVersion)
            schemaVersion = 4
            game = try c.decode(Game.self, forKey: .game)
            difficulty = try? c.decodeIfPresent(Difficulty.self, forKey: .difficulty)
            switch version {
            case 2:
                // v2 only had Desafiador-style lives.
                let lives = try c.decode(Int.self, forKey: .lives)
                guard (0...Self.maxLives).contains(lives) else { throw PuzzleError.invalidSession }
                mistakes = Self.maxLives - lives
            case 3, 4:
                mistakes = try c.decode(Int.self, forKey: .mistakes)
                guard mistakes >= 0 else { throw PuzzleError.invalidSession }
                // v3 Tranquilo walks had no lives; keep them playable (or won) under the new rule.
                if version == 3 { mistakes = min(mistakes, Self.maxLives - 1) }
                guard mistakes <= Self.maxLives else { throw PuzzleError.invalidSession }
            default: throw PuzzleError.invalidSession
            }
            guard !(defeated && game.won) else { throw PuzzleError.invalidSession }
        } else {
            // Old PC-003 saved Game format had no lives.
            schemaVersion = 4; game = try Game(from: decoder); mistakes = 0; difficulty = nil
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(game, forKey: .game)
        try c.encode(mistakes, forKey: .mistakes)
        try c.encodeIfPresent(difficulty, forKey: .difficulty)
    }
}

public enum MoveAssessment: Sendable, Equatable { case accepted, penalty(StrokeViolation), cancelled }
public enum AttemptRules {
    /// Only mistakes the player can see on the board are penalized: exceeding a clue,
    /// arriving home early, stepping on a shrub or crossing the route. Dead ends that
    /// only a solver could foresee are left for the player to discover.
    public static func assess(stroke: GameStroke, isCancelled: () -> Bool = { false }) -> MoveAssessment {
        if isCancelled() { return .cancelled }
        if let violation = stroke.violation { return .penalty(violation) }
        return .accepted
    }
}

import Foundation

/// Tranquilo never ends a walk; Desafiador ends it after three visible mistakes.
public enum PlayMode: String, Codable, CaseIterable, Sendable {
    case relaxed, challenging
    public var title: String { self == .relaxed ? String(localized: "Tranquilo") : String(localized: "Desafiador") }
    public var hasLives: Bool { self == .challenging }
}

/// Mistakes are outside Game's undo history. Defeat and score are derived, never separately mutable.
public struct GameAttempt: Codable, Sendable {
    public static let maxLives = 3
    public let schemaVersion: Int
    public internal(set) var game: Game
    public let mode: PlayMode
    public internal(set) var mistakes: Int
    public var lives: Int { max(0, Self.maxLives - mistakes) }
    public var defeated: Bool { mode.hasLives && lives == 0 }
    /// Score shown as paw prints: 3 for a clean walk, never below 1 once home.
    public var paws: Int { max(1, Self.maxLives - mistakes) }
    public init(game: Game = Game(), mode: PlayMode = .challenging) {
        schemaVersion = 3; self.game = game; self.mode = mode; mistakes = 0
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, game, lives, mode, mistakes }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.game) {
            let version = try c.decode(Int.self, forKey: .schemaVersion)
            schemaVersion = 3
            game = try c.decode(Game.self, forKey: .game)
            switch version {
            case 2:
                // v2 only had Desafiador-style lives.
                let lives = try c.decode(Int.self, forKey: .lives)
                guard (0...Self.maxLives).contains(lives) else { throw PuzzleError.invalidSession }
                mode = .challenging; mistakes = Self.maxLives - lives
            case 3:
                mode = try c.decode(PlayMode.self, forKey: .mode)
                mistakes = try c.decode(Int.self, forKey: .mistakes)
                guard mistakes >= 0, !mode.hasLives || mistakes <= Self.maxLives else { throw PuzzleError.invalidSession }
            default: throw PuzzleError.invalidSession
            }
            guard !(defeated && game.won) else { throw PuzzleError.invalidSession }
        } else {
            // Old PC-003 saved Game format had no lives.
            schemaVersion = 3; game = try Game(from: decoder); mode = .challenging; mistakes = 0
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(game, forKey: .game)
        try c.encode(mode, forKey: .mode)
        try c.encode(mistakes, forKey: .mistakes)
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

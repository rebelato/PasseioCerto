import Foundation

/// Lives are outside Game's undo history. Defeat is derived, never separately mutable.
public struct GameAttempt: Codable, Sendable {
    public let schemaVersion: Int
    public internal(set) var game: Game
    public internal(set) var lives: Int
    public var defeated: Bool { lives == 0 }
    public init(game: Game = Game()) { schemaVersion = 2; self.game = game; lives = 3 }
    private enum CodingKeys: String, CodingKey { case schemaVersion, game, lives }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.game) {
            schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
            game = try c.decode(Game.self, forKey: .game)
            lives = try c.decode(Int.self, forKey: .lives)
            guard schemaVersion == 2, (0...3).contains(lives), !(lives == 0 && game.won) else { throw PuzzleError.invalidSession }
        } else {
            // Old PC-003 saved Game format had no lives.
            schemaVersion = 2; game = try Game(from: decoder); lives = 3
        }
    }
}

public enum MoveAssessment: Sendable, Equatable { case accepted, penalty, inconclusive, cancelled }
public enum AttemptRules {
    public static func assess(before: Game, stroke: GameStroke, nodeLimit: Int = 100_000,
                              isCancelled: () -> Bool = { false }) -> MoveAssessment {
        if isCancelled() { return .cancelled }
        if stroke.penaltyDetected { return .penalty }
        let after = stroke.finish()
        if before.path == after.path { return .accepted } // marks or no-op
        let next = ExactSolver.solve(puzzle: after.puzzle, prefix: after.path, nodeLimit: nodeLimit, isCancelled: isCancelled)
        if isCancelled() { return .cancelled }
        switch next.classification {
        case .unique, .multiple: return .accepted
        case .indeterminate: return .inconclusive
        case .noSolution:
            // Ignore × in both queries: annotations never make a legal move cost a life.
            let previous = ExactSolver.solve(puzzle: before.puzzle, prefix: before.path, nodeLimit: nodeLimit, isCancelled: isCancelled)
            if isCancelled() { return .cancelled }
            switch previous.classification {
            case .unique, .multiple: return .penalty
            case .indeterminate: return .inconclusive
            case .noSolution: return .accepted // don't penalize a preexisting dead end
            }
        }
    }
}

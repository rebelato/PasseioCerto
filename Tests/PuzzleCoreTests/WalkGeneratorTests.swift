import XCTest
@testable import PuzzleCore
final class WalkGeneratorTests: XCTestCase {
    func testEveryDifficultyMakesALogicSolvableWalkWithNoEmptyClue() throws {
        for difficulty in Difficulty.allCases {
            let r = WalkGenerator.generate(difficulty, variation: 7)
            let p = try XCTUnwrap(r.puzzle, "\(difficulty)")
            XCTAssertEqual(p.rows.count, difficulty.size)
            XCTAssertEqual(p.columns.count, difficulty.size)
            XCTAssertFalse(p.rows.contains(0), "\(difficulty) rows")
            XCTAssertFalse(p.columns.contains(0), "\(difficulty) columns")
            XCTAssertTrue(p.obstacles.isEmpty)
            XCTAssertEqual(p.hiddenGoal, difficulty != .easy, "Only Fácil shows the house")
            let route = try XCTUnwrap(PuzzleSolution.route(for: p))
            XCTAssertEqual(route.first, p.start)
            XCTAssertEqual(route.last, p.goal)
            XCTAssertEqual(RouteValidator.evaluate(puzzle: p, path: route), .complete)
            XCTAssertEqual(WalkGenerator.generate(difficulty, variation: 7).puzzle, p, "Same variation, same walk")
            XCTAssertNotEqual(WalkGenerator.generate(difficulty, variation: 8).puzzle?.rows, nil)
        }
    }
    /// Logic solving the whole walk must mean it is the only one: checked exhaustively on small sizes.
    func testLogicSolvedWalksAreUnique() {
        for difficulty in [Difficulty.easy, .medium] {
            for variation in UInt64(1)...15 {
                guard let p = WalkGenerator.generate(difficulty, variation: variation).puzzle else { continue }
                XCTAssertEqual(ExactSolver.solve(puzzle: p, nodeLimit: 2_000_000).classification, .unique, p.puzzleID)
            }
        }
    }
    func testReservesAreCertified() throws {
        for difficulty in Difficulty.allCases {
            let reserves = try XCTUnwrap(FallbackCatalog.walks[difficulty])
            XCTAssertGreaterThanOrEqual(reserves.count, 2)
            for p in reserves {
                XCTAssertEqual(p.rows.count, difficulty.size)
                XCTAssertEqual(p.hiddenGoal, difficulty.hiddenHouse)
                XCTAssertEqual(LogicEngine.analyze(puzzle: p, maxTier: LogicEngine.fullTier).outcome, .solved, p.puzzleID)
            }
        }
        let fallback = WalkGenerator.generate(.expert, variation: 3, candidateLimit: 0)
        XCTAssertEqual(fallback.outcome, .fallback)
        XCTAssertEqual(fallback.puzzle?.rows.count, 20)
        XCTAssertEqual(WalkGenerator.generate(.easy, variation: 1, isCancelled: { true }).outcome, .cancelled)
    }
    @MainActor func testPlayUsesTheChosenDifficultyAndPrefetchesTheNext() async throws {
        let s = GameSession(prefetches: true)
        s.setDifficulty(.medium)
        await s.play()
        XCTAssertEqual(s.attempt.difficulty, .medium)
        XCTAssertEqual(s.attempt.game.puzzle.rows.count, 7)
        XCTAssertTrue(s.attempt.game.puzzle.hiddenGoal)
        let first = s.attempt.game.puzzle.puzzleID
        try await Task.sleep(for: .milliseconds(300)) // the next medium walk is prepared meanwhile
        await s.replay()
        XCTAssertFalse(s.generating)
        XCTAssertNotEqual(s.attempt.game.puzzle.puzzleID, first)
    }
}

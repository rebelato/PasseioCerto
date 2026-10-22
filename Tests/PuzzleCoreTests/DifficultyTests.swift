import XCTest
@testable import PuzzleCore
final class DifficultyTests: XCTestCase {
    func testCatalogCertifiedAndSeparatedByLogicNotSize() {
        XCTAssertEqual(Set(FallbackCatalog.puzzles.map(\.puzzleID)).count, 4)
        for (index, puzzle) in FallbackCatalog.puzzles.enumerated() {
            XCTAssertEqual(puzzle.rows.count, 5)
            XCTAssertEqual(ExactSolver.solve(puzzle: puzzle).classification, .unique)
            XCTAssertEqual(LogicEngine.analyze(puzzle: puzzle).outcome, .solved)
            XCTAssertEqual(DifficultyClassifier.assess(puzzle)?.level, index < 2 ? .relaxed : .challenging)
        }
    }
    func testUnsolvedPuzzleHasNoDifficultyRating() throws {
        XCTAssertNil(DifficultyClassifier.assess(try PuzzleFixtures.ambiguous.makePuzzle()))
        XCTAssertNil(DifficultyClassifier.assess(try PuzzleFixtures.disconnected.makePuzzle()))
    }
    func testRequestedDifficultyRespectedForGeneratedAndFallback() throws {
        for level in PuzzleDifficulty.allCases {
            for seed in UInt64(0)..<10 {
                for budget in [0,80] {
                    let result = PuzzleGenerator.generate(seed: seed, difficulty: level, candidateLimit: budget)
                    let p = try XCTUnwrap(result.puzzle)
                    XCTAssertEqual(DifficultyClassifier.assess(p)?.level, level)
                    XCTAssertEqual(ExactSolver.solve(puzzle: p).classification, .unique)
                    XCTAssertEqual(result.candidates, result.rejectedBySolver + result.rejectedByLogic + result.rejectedByDifficulty + (result.outcome == .generated ? 1 : 0))
                    if budget == 0 { XCTAssertTrue(p.puzzleID.hasPrefix("reserve-v1-")) }
                }
            }
        }
    }
    func testCancellationDoesNotReturnFallback() {
        for level in PuzzleDifficulty.allCases {
            let r = PuzzleGenerator.generate(seed: 0, difficulty: level, isCancelled: { true })
            XCTAssertEqual(r.outcome, .cancelled)
            XCTAssertNil(r.puzzle)
        }
    }
}

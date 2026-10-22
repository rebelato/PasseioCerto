import XCTest
@testable import PuzzleCore
final class PuzzleGeneratorTests: XCTestCase {
    func testSeedCorpusPassesBothValidatorsAndIsReproducible() throws {
        var generated = 0
        var fallback = 0
        var attempts = 0
        var solverRejected = 0
        var logicRejected = 0
        var identities: [String: Puzzle] = [:]
        for seed in UInt64(0)..<50 {
            let a = PuzzleGenerator.generate(seed: seed)
            let b = PuzzleGenerator.generate(seed: seed)
            XCTAssertEqual(a.puzzle, b.puzzle)
            XCTAssertEqual(a.outcome, b.outcome)
            XCTAssertEqual(a.candidates, b.candidates)
            let p = try XCTUnwrap(a.puzzle)
            if let existing = identities[p.puzzleID] { XCTAssertEqual(existing, p) }
            identities[p.puzzleID] = p
            XCTAssertEqual(ExactSolver.solve(puzzle: p).classification, .unique)
            XCTAssertEqual(LogicEngine.analyze(puzzle: p).outcome, .solved)
            XCTAssertEqual(p.rows.count, 5)
            XCTAssertEqual(p.columns.count, 5)
            attempts += a.candidates; solverRejected += a.rejectedBySolver; logicRejected += a.rejectedByLogic
            if a.outcome == .generated { generated += 1 } else { fallback += 1 }
        }
        XCTAssertGreaterThan(generated, 0)
        XCTAssertGreaterThan(identities.count, 1)
        print("GENERATOR CORPUS seeds=0...49 generated=\(generated) fallback=\(fallback) candidates=\(attempts) rejectedSolver=\(solverRejected) rejectedLogic=\(logicRejected)")
    }
    func testBudgetExhaustionCannotPublishUnverifiedCandidate() throws {
        let empty = PuzzleGenerator.generate(seed: 1, candidateLimit: 0)
        XCTAssertEqual(empty.outcome, .fallback)
        let limited = PuzzleGenerator.generate(seed: 1, candidateLimit: 3, solverNodeLimit: 0)
        XCTAssertEqual(limited.outcome, .fallback)
        XCTAssertEqual(limited.candidates, 3)
        XCTAssertEqual(limited.rejectedBySolver, 3)
        XCTAssertEqual(limited.puzzle, empty.puzzle)
        XCTAssertEqual(limited.puzzle?.puzzleID, PuzzleFixtures.approved.id)
    }
    func testCancellationDiscardsWorkAndReplayKeepsIdentity() {
        let immediate = PuzzleGenerator.generate(seed: 42, isCancelled: { true })
        XCTAssertEqual(immediate.outcome, .cancelled)
        XCTAssertNil(immediate.puzzle)
        var checks = 0
        let interrupted = PuzzleGenerator.generate(seed: 42, isCancelled: { checks += 1; return checks > 5 })
        XCTAssertEqual(interrupted.outcome, .cancelled)
        XCTAssertNil(interrupted.puzzle)
        XCTAssertEqual(PuzzleGenerator.generate(seed: 42).puzzle, PuzzleGenerator.generate(seed: 42).puzzle)
    }
    func testExtremeSeedsAndNegativeBudgets() {
        for seed in [UInt64.max, UInt64.max-1, 1 << 63] {
            let r = PuzzleGenerator.generate(seed: seed)
            XCTAssertNotNil(r.puzzle)
            XCTAssertLessThanOrEqual(r.candidates, 80)
        }
        XCTAssertEqual(PuzzleGenerator.generate(seed: 1, candidateLimit: -10).outcome, .fallback)
    }
}

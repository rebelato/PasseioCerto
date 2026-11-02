import XCTest
import Foundation
@testable import PuzzleCore

private actor GenerationGate {
    var pending: [UInt64: CheckedContinuation<GenerationReport, Never>] = [:]
    func wait(_ seed: UInt64) async -> GenerationReport {
        await withCheckedContinuation { pending[seed] = $0 }
    }
    func ready(_ seed: UInt64) -> Bool { pending[seed] != nil }
    func finish(_ seed: UInt64) {
        pending.removeValue(forKey: seed)?.resume(returning: PuzzleGenerator.generate(seed: seed))
    }
}
final class GenerationSessionTests: XCTestCase {
    @MainActor func testGeneratedDifficultyIsSavedWithFreshLives() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("save.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let s = GameSession(saveURL: url)
        await s.newPuzzle(difficulty: .challenging, seed: 2)
        XCTAssertFalse(s.generating)
        XCTAssertEqual(DifficultyClassifier.assess(s.attempt.game.puzzle)?.level, .challenging)
        XCTAssertEqual(s.attempt.lives, 3)
        XCTAssertFalse(s.attempt.game.canUndo)
        XCTAssertEqual(GameSession(saveURL: url).attempt.game.puzzle, s.attempt.game.puzzle)
    }
    @MainActor func testExhaustedBudgetUsesIdentifiableVerifiedReserve() async {
        let s = GameSession(generate: { seed, difficulty in
            PuzzleGenerator.generate(seed: seed, difficulty: difficulty, candidateLimit: 0)
        })
        await s.newPuzzle(difficulty: .relaxed, seed: 0)
        XCTAssertEqual(s.attempt.game.puzzle, FallbackCatalog.puzzle(for: .relaxed, seed: 0))
        XCTAssertNil(s.message, "Reserve puzzles are used silently")
        XCTAssertEqual(ExactSolver.solve(puzzle: s.attempt.game.puzzle).classification, .unique)
        XCTAssertEqual(LogicEngine.analyze(puzzle: s.attempt.game.puzzle).outcome, .solved)
    }
    @MainActor func testErrorPreservesAttempt() async {
        struct Failure: Error {}
        let s = GameSession(generate: { _, _ in throw Failure() })
        await s.select(Cell(0,1), marking: true)
        let before = s.attempt.game
        await s.newPuzzle(difficulty: .relaxed, seed: 0)
        XCTAssertEqual(s.attempt.game.marks, before.marks)
        XCTAssertEqual(s.attempt.game.path, before.path)
        XCTAssertFalse(s.generating)
        XCTAssertTrue(s.message?.contains("tente novamente") == true)
    }
    @MainActor func testCancellationAndBackgroundDiscardUncooperativeWorker() async {
        for background in [false, true] {
            let gate = GenerationGate()
            let s = GameSession(generate: { seed, _ in await gate.wait(seed) })
            let original = s.attempt.game.puzzle
            let request = Task { await s.newPuzzle(difficulty: .relaxed, seed: 5) }
            while !(await gate.ready(5)) { await Task.yield() }
            XCTAssertTrue(s.generating); XCTAssertFalse(s.canInteract)
            if background { s.suspend() } else { s.cancelGeneration() }
            await gate.finish(5); await request.value
            XCTAssertFalse(s.generating)
            XCTAssertEqual(s.attempt.game.puzzle, original)
        }
    }
    @MainActor func testOldResponseCannotOverwriteNewRequest() async {
        let gate = GenerationGate()
        let s = GameSession(generate: { seed, _ in await gate.wait(seed) })
        let first = Task { await s.newPuzzle(difficulty: .relaxed, seed: 1) }
        while !(await gate.ready(1)) { await Task.yield() }
        let second = Task { await s.newPuzzle(difficulty: .relaxed, seed: 2) }
        while !(await gate.ready(2)) { await Task.yield() }
        await gate.finish(2); await second.value
        let newest = s.attempt.game.puzzle
        await gate.finish(1); await first.value
        XCTAssertEqual(s.attempt.game.puzzle, newest)
        XCTAssertEqual(newest.seed, 2)
        XCTAssertFalse(s.generating)
    }
}

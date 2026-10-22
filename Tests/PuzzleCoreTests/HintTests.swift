import XCTest
import Foundation
@testable import PuzzleCore
final class HintTests: XCTestCase {
    func testHintIsFirstFactWithCoordinatesAndClue() {
        let game = Game()
        let first = LogicEngine.analyze(puzzle: game.puzzle).deductions[0]
        let hint = HintProvider.advice(for: game)
        XCTAssertEqual(hint.kind, .deduction)
        switch first.action {
        case .required(let c), .excluded(let c), .extend(let c):
            XCTAssertEqual(hint.cells, [c])
            XCTAssertTrue(hint.text.contains("Linha \(c.row+1), coluna \(c.col+1)"))
        }
        XCTAssertTrue(hint.row != nil || hint.column != nil)
    }
    func testConflictingMarksDoNotProduceAnInventedHint() {
        var game = Game(); game.play(Cell(0,1), marking: true)
        let hint = HintProvider.advice(for: game)
        XCTAssertEqual(hint.kind, .conflict)
        XCTAssertTrue(hint.cells.isEmpty)
    }
    func testCompletedAndUnavailableStates() throws {
        var game = Game()
        for c in PuzzleFixtures.approved.witnessRoutes[0].dropFirst() { game.play(c) }
        XCTAssertEqual(HintProvider.advice(for: game).kind, .completed)
        let p = try Puzzle(puzzleID: "no-rule", rows: [2,2,2], columns: [2,2,2], start: Cell(0,0), goal: Cell(2,2))
        XCTAssertEqual(HintProvider.advice(for: Game(puzzle: p)).kind, .unavailable)
    }
    @MainActor func testRequestAndDismissDoNotChangeAttemptOrChargeLives() async throws {
        let session = GameSession()
        let before = try JSONEncoder().encode(session.attempt)
        await session.requestHint()
        XCTAssertNotNil(session.hint)
        session.dismissHint()
        XCTAssertNil(session.hint)
        let restored = try JSONDecoder().decode(GameAttempt.self, from: before)
        XCTAssertEqual(session.attempt.game.path, restored.game.path)
        XCTAssertEqual(session.attempt.game.marks, restored.game.marks)
        XCTAssertEqual(session.attempt.lives, restored.lives)
        XCTAssertFalse(session.attempt.game.canUndo)
    }
    @MainActor func testMovesRestartAndBackgroundInvalidateHints() async {
        let s = GameSession()
        await s.requestHint(); s.begin(at: Cell(0,1), marking: false)
        XCTAssertNil(s.hint); await s.finish()
        let pending = Task { await s.requestHint() }
        await Task.yield(); s.restart(); await pending.value
        XCTAssertNil(s.hint); XCTAssertFalse(s.hintChecking)
        await s.requestHint(); s.suspend(); XCTAssertNil(s.hint)
    }
}

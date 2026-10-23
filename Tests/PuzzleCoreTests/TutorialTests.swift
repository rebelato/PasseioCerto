import XCTest
import Foundation
@testable import PuzzleCore

final class TutorialTests: XCTestCase {
    @MainActor func testLessonRequiresActionsAndUsesRealRules() {
        let t = TutorialSession(step: 0)
        XCTAssertEqual(t.game.rowCounts, [1,0,1]) // both endpoints count
        t.select(Cell(1,1)); XCTAssertEqual(t.step, 0)
        t.undo(); t.requestHint(); XCTAssertEqual(t.step, 0)
        t.select(Cell(0,1)); XCTAssertEqual(t.step, 1)
        t.select(Cell(1,1)); XCTAssertEqual(t.step, 2)
        t.select(Cell(0,2)); XCTAssertEqual(t.step, 3)
        XCTAssertTrue(t.game.marks.contains(Cell(0,2)))
        t.undo(); XCTAssertEqual(t.step, 4)
        XCTAssertTrue(t.game.marks.isEmpty)
        let route = t.game.path
        t.requestHint(); XCTAssertEqual(t.step, 5)
        XCTAssertEqual(t.hint?.kind, .deduction)
        XCTAssertEqual(t.game.path, route)
        t.select(Cell(2,2)); XCTAssertEqual(t.step, 5) // diagonal cannot finish
        t.select(Cell(2,1)); XCTAssertEqual(t.step, 5)
        t.select(Cell(2,2)); XCTAssertEqual(t.step, 6)
        XCTAssertTrue(t.game.won)
        XCTAssertEqual(RouteValidator.evaluate(puzzle: t.game.puzzle, path: t.game.path), .complete)
        XCTAssertEqual(ExactSolver.solve(puzzle: t.game.puzzle).classification, .unique)
    }
    @MainActor func testEveryCheckpointCanResumeAndFinish() {
        for checkpoint in 0..<TutorialSession.completedStep {
            let t = TutorialSession(step: checkpoint)
            for _ in 0..<8 {
                if let cell = t.target { t.select(cell) }
                else if t.step == 3 { t.undo() }
                else if t.step == 4 { t.requestHint() }
            }
            XCTAssertEqual(t.step, TutorialSession.completedStep)
            XCTAssertTrue(t.game.won)
        }
    }
    @MainActor func testProgressPersistsWithoutReplacingNormalAttemptOrRewards() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("save.json")
        let s = GameSession(saveURL: url)
        await s.select(Cell(0,1), marking: false)
        let normal = s.attempt.game
        for checkpoint in [2,5,6,0] { // resume, complete/skip, repeat
            s.setTutorialStep(checkpoint)
            let restored = GameSession(saveURL: url)
            XCTAssertEqual(restored.tutorialStep, checkpoint)
            XCTAssertEqual(restored.attempt.game.path, normal.path)
            XCTAssertEqual(restored.attempt.game.puzzle, normal.puzzle)
            XCTAssertTrue(restored.completedPuzzleIDs.isEmpty)
        }
    }
}

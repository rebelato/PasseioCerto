import XCTest
import Foundation
@testable import PuzzleCore
final class GameSessionTests: XCTestCase {
    @MainActor func testThreeErrorsDefeatAndRestartSamePuzzle() async {
        let s = GameSession()
        for lives in [2,1,0] {
            s.begin(at: Cell(1,0), marking: false) // orthogonal but column exceeds clue
            s.move(to: Cell(1,0)); s.move(to: Cell(1,0))
            await s.finish()
            XCTAssertEqual(s.attempt.lives, lives)
            XCTAssertEqual(s.attempt.game.path, [Cell(0,0)])
        }
        XCTAssertTrue(s.attempt.defeated)
        await s.select(Cell(0,1), marking: false)
        XCTAssertEqual(s.attempt.game.path.count, 1)
        s.undo(); XCTAssertEqual(s.attempt.lives, 0)
        let id = s.attempt.game.puzzle.puzzleID
        s.restart()
        XCTAssertEqual(s.attempt.game.puzzle.puzzleID, id)
        XCTAssertEqual(s.attempt.lives, 3)
        XCTAssertFalse(s.attempt.game.canUndo)
    }
    @MainActor func testUndoDoesNotRefundAndMarksNeverCost() async {
        let s = GameSession()
        await s.select(Cell(0,1), marking: false)
        await s.select(Cell(1,1), marking: false)
        XCTAssertEqual(s.attempt.lives, 2)
        s.undo()
        XCTAssertEqual(s.attempt.game.path.count, 1)
        XCTAssertEqual(s.attempt.lives, 2)
        await s.select(Cell(0,1), marking: true)
        XCTAssertEqual(s.attempt.lives, 2)
        await s.select(Cell(0,1), marking: false) // × conflict: no penalty
        XCTAssertEqual(s.attempt.lives, 2)
    }
    @MainActor func testInvalidAndCancelledGesturesAreFree() async {
        let s = GameSession()
        for c in [Cell(-1,0),Cell(1,1),Cell(0,4)] { await s.select(c, marking: false) }
        XCTAssertEqual(s.attempt.lives, 3)
        s.begin(at: Cell(1,0), marking: false)
        await s.finish(cancelled: true)
        XCTAssertEqual(s.attempt.lives, 3)
        XCTAssertFalse(s.attempt.game.canUndo)
    }
    @MainActor func testIndeterminateRevertsWithoutPenalty() async {
        let s = GameSession(nodeLimit: 0)
        await s.select(Cell(0,1), marking: false)
        XCTAssertEqual(s.attempt.lives, 3)
        XCTAssertEqual(s.attempt.game.path.count, 1)
        XCTAssertTrue(s.message.contains("sem perder vida"))
    }
    @MainActor func testRestartDiscardsPendingResult() async {
        let s = GameSession()
        s.begin(at: Cell(1,0), marking: false)
        let pending = Task { await s.finish() }
        await Task.yield()
        s.restart()
        await pending.value
        XCTAssertEqual(s.attempt.lives, 3)
        XCTAssertEqual(s.attempt.game.path.count, 1)
        XCTAssertFalse(s.checking)
    }
    @MainActor func testDefeatPersistsAndLegacyMigrates() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("attempt.json")
        let s = GameSession(saveURL: url)
        for _ in 0..<3 { await s.select(Cell(1,0), marking: false) }
        let restored = GameSession(saveURL: url)
        XCTAssertEqual(restored.attempt.lives, 0)
        XCTAssertTrue(restored.attempt.defeated)
        restored.restart()
        XCTAssertEqual(GameSession(saveURL: url).attempt.lives, 3)
        try JSONEncoder().encode(Game()).write(to: url)
        XCTAssertEqual(GameSession(saveURL: url).attempt.lives, 3)
        let invalid = Data("broken".utf8)
        try invalid.write(to: url)
        let broken = GameSession(saveURL: url)
        XCTAssertNotNil(broken.storageError)
        broken.restart()
        XCTAssertEqual(try Data(contentsOf: url), invalid)
    }
    func testLocallyLegalDeadEndCostsLifeButMarksAreIgnored() throws {
        let puzzle = try Puzzle(puzzleID: "dead-end", rows: [3,2,2], columns: [1,3,3], start: Cell(0,0), goal: Cell(2,2))
        var before = Game(puzzle: puzzle)
        before.play(Cell(0,1))
        var stroke = GameStroke(game: before, marking: false)
        XCTAssertTrue(stroke.move(to: Cell(1,1)))
        XCTAssertFalse(stroke.penaltyDetected)
        XCTAssertEqual(AttemptRules.assess(before: before, stroke: stroke), .penalty)
        var marked = Game()
        marked.play(Cell(0,2), marking: true) // incorrect annotation beyond the next move
        var valid = GameStroke(game: marked, marking: false)
        valid.move(to: Cell(0,1))
        XCTAssertEqual(AttemptRules.assess(before: marked, stroke: valid), .accepted)
    }
    @MainActor func testCompleteGestureFreezesVictoryUntilReplay() async {
        let s = GameSession()
        let route = PuzzleFixtures.approved.witnessRoutes[0]
        s.begin(at: route[0], marking: false)
        for cell in route.dropFirst() { s.move(to: cell) }
        await s.finish()
        XCTAssertTrue(s.attempt.game.won)
        XCTAssertEqual(s.attempt.lives, 3)
        XCTAssertTrue(s.celebrating)
        s.undo()
        XCTAssertTrue(s.attempt.game.won)
        s.finishCelebration()
        XCTAssertFalse(s.celebrating)
        XCTAssertTrue(s.attempt.game.won)
        s.restart()
        XCTAssertFalse(s.attempt.game.won)
        XCTAssertEqual(s.attempt.game.path.count, 1)
    }
    @MainActor func testInterruptedCelebrationPersistsOneVictoryAndDoesNotReplay() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("save.json")
        let session = GameSession(saveURL: url)
        for cell in PuzzleFixtures.approved.witnessRoutes[0].dropFirst() {
            await session.select(cell, marking: false)
        }
        XCTAssertTrue(session.celebrating)
        XCTAssertEqual(session.completedPuzzleIDs.count, 1)
        let route = session.attempt.game.path
        await session.select(Cell(0,1), marking: true)
        XCTAssertEqual(session.attempt.game.path, route)
        session.suspend()
        XCTAssertFalse(session.celebrating)
        let restored = GameSession(saveURL: url)
        XCTAssertTrue(restored.attempt.game.won)
        XCTAssertFalse(restored.celebrating)
        restored.finishCelebration(); restored.suspend()
        XCTAssertEqual(restored.completedPuzzleIDs.count, 1)
        XCTAssertEqual(restored.attempt.game.path, route)
    }
    func testInvalidLifeCountsRejected() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(GameAttempt())) as? [String: Any])
        for lives in [-1,4] {
            json["lives"] = lives
            XCTAssertThrowsError(try JSONDecoder().decode(GameAttempt.self, from: JSONSerialization.data(withJSONObject: json)))
        }
    }
    func testEarlyArrivalPenalizedAndCancellationOverridesIt() throws {
        let p = try Puzzle(puzzleID: "early", rows: [2,2], columns: [2,2], start: Cell(0,0), goal: Cell(0,1))
        let game = Game(puzzle: p)
        var stroke = GameStroke(game: game, marking: false)
        stroke.move(to: p.goal)
        XCTAssertEqual(AttemptRules.assess(before: game, stroke: stroke), .penalty)
        XCTAssertEqual(AttemptRules.assess(before: game, stroke: stroke, isCancelled: { true }), .cancelled)
    }
}

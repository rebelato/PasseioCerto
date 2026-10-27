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
    @MainActor func testVisibleMistakesAreShownThenCleared() async throws {
        let s = GameSession()
        await s.select(Cell(1,0), marking: false) // column 1 already full
        XCTAssertEqual(s.violation, StrokeViolation(kind: .columnExceeded, cell: Cell(1,0), column: 0))
        XCTAssertTrue(s.message?.contains("coluna 1") == true)
        XCTAssertEqual(s.attempt.game.path, [Cell(0,0)])
        try await Task.sleep(for: .milliseconds(700))
        XCTAssertNil(s.violation)
        s.begin(at: Cell(0,1), marking: false)
        XCTAssertNil(s.displayedViolation)
    }
    @MainActor func testEveryWalkEndsAfterThreeMistakes() async {
        let s = GameSession(attempt: GameAttempt(difficulty: .easy))
        for _ in 0..<3 { await s.select(Cell(1,0), marking: false) }
        XCTAssertTrue(s.attempt.defeated)
        XCTAssertFalse(s.canInteract)
        s.restart()
        XCTAssertEqual(s.attempt.difficulty, .easy)
        XCTAssertEqual(s.attempt.mistakes, 0)
    }
    @MainActor func testPawsRewardCleanWalksAndKeepBest() async {
        let s = GameSession()
        let route = PuzzleFixtures.approved.witnessRoutes[0]
        await s.select(Cell(1,0), marking: false)
        for cell in route.dropFirst() { await s.select(cell, marking: false) }
        XCTAssertEqual(s.attempt.paws, 2)
        XCTAssertEqual(s.bestPaws[s.attempt.game.puzzle.puzzleID], 2)
        s.restart()
        for cell in route.dropFirst() { await s.select(cell, marking: false) }
        XCTAssertEqual(s.bestPaws[s.attempt.game.puzzle.puzzleID], 3)
        s.restart()
        for _ in 0..<2 { await s.select(Cell(1,0), marking: false) }
        for cell in route.dropFirst() { await s.select(cell, marking: false) }
        XCTAssertEqual(s.attempt.paws, 1)
        XCTAssertEqual(s.bestPaws[s.attempt.game.puzzle.puzzleID], 3)
    }
    @MainActor func testReplayBringsANewGridOfTheSameLevel() async {
        let made = ManagedCounter()
        let s = GameSession(generateWalk: { difficulty, variation, _ in
            await made.add()
            let p = try Puzzle(puzzleID: "walk-\(difficulty.rawValue)-\(variation)", rows: [2,0], columns: [1,1], start: Cell(0,0), goal: Cell(0,1))
            return GenerationReport(outcome: .generated, puzzle: p, candidates: 1, rejectedBySolver: 0, rejectedByLogic: 0, rejectedByDifficulty: 0)
        })
        await s.play(.hard)
        let first = s.attempt.game.puzzle.puzzleID
        await s.select(Cell(0,1), marking: false)
        await s.replay()
        XCTAssertEqual(s.attempt.difficulty, .hard)
        XCTAssertNotEqual(s.attempt.game.puzzle.puzzleID, first)
        XCTAssertFalse(s.attempt.game.won)
        let calls = await made.value
        XCTAssertEqual(calls, 2)
    }
    @MainActor func testRestartDiscardsPendingResult() async {
        let s = GameSession()
        s.begin(at: Cell(1,0), marking: false)
        let pending = Task { await s.finish() }
        await Task.yield()
        s.restart()
        await pending.value
        XCTAssertEqual(s.attempt.game.path.count, 1)
        XCTAssertNil(s.stroke)
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
    func testDeadEndsAreLeftToDiscoverButMarksAreIgnored() throws {
        let puzzle = try Puzzle(puzzleID: "dead-end", rows: [3,2,2], columns: [1,3,3], start: Cell(0,0), goal: Cell(2,2))
        var before = Game(puzzle: puzzle)
        before.play(Cell(0,1))
        var stroke = GameStroke(game: before, marking: false)
        XCTAssertTrue(stroke.move(to: Cell(1,1)))
        XCTAssertFalse(stroke.penaltyDetected)
        XCTAssertEqual(AttemptRules.assess(stroke: stroke), .accepted)
        var marked = Game()
        marked.play(Cell(0,2), marking: true) // incorrect annotation beyond the next move
        var valid = GameStroke(game: marked, marking: false)
        valid.move(to: Cell(0,1))
        XCTAssertEqual(AttemptRules.assess(stroke: valid), .accepted)
    }
    func testShrubsAndCrossingThePathArePenalized() throws {
        let puzzle = try Puzzle(puzzleID: "shrub", rows: [2,3,1], columns: [2,2,2], start: Cell(0,0), goal: Cell(2,2), obstacles: [Cell(0,2)])
        var game = Game(puzzle: puzzle)
        var shrub = GameStroke(game: game, marking: false)
        shrub.move(to: Cell(0,1)); shrub.move(to: Cell(0,2))
        XCTAssertEqual(shrub.violation?.kind, .obstacle)
        for cell in [Cell(0,1), Cell(1,1), Cell(1,0)] { game.play(cell) }
        var cross = GameStroke(game: game, marking: false)
        cross.move(to: Cell(0,0))
        XCTAssertEqual(cross.violation?.kind, .crossedPath)
        var back = GameStroke(game: game, marking: false)
        back.move(to: Cell(1,1))
        XCTAssertNil(back.violation, "Stepping back onto the previous cell is ignored")
        XCTAssertEqual(back.preview.path.count, 4)
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
        for mistakes in [-1,4] {
            json["mistakes"] = mistakes
            XCTAssertThrowsError(try JSONDecoder().decode(GameAttempt.self, from: JSONSerialization.data(withJSONObject: json)))
        }
    }
    func testEarlyArrivalPenalizedAndCancellationOverridesIt() throws {
        let p = try Puzzle(puzzleID: "early", rows: [2,2], columns: [2,2], start: Cell(0,0), goal: Cell(0,1))
        let game = Game(puzzle: p)
        var stroke = GameStroke(game: game, marking: false)
        stroke.move(to: p.goal)
        XCTAssertEqual(AttemptRules.assess(stroke: stroke), .penalty(StrokeViolation(kind: .arrivedEarly, cell: p.goal)))
        XCTAssertEqual(AttemptRules.assess(stroke: stroke, isCancelled: { true }), .cancelled)
    }
}

final class TapTests: XCTestCase {
    @MainActor func testEveryTapIsAnAttemptAndHoldingMarks() async {
        // Approved route: (0,0) (0,1) (0,2) (1,2) (2,2) (2,3) (2,4) (3,4) (4,4)
        let s = GameSession()
        await s.tap(Cell(0,1))
        XCTAssertEqual(s.attempt.game.path, [Cell(0,0), Cell(0,1)], "Tap next to the tip continues the route")
        await s.tap(Cell(3,3), held: true)
        XCTAssertEqual(s.attempt.game.marks, [Cell(3,3)], "Holding marks ×, for free")
        await s.tap(Cell(3,3), held: true)
        XCTAssertTrue(s.attempt.game.marks.isEmpty, "Holding again clears it")
        await s.tap(Cell(2,3))
        XCTAssertEqual(s.attempt.mistakes, 0, "A far cell that is on the route is not a mistake, just not next yet")
        await s.tap(Cell(0,0))
        XCTAssertEqual(s.attempt.game.path, [Cell(0,0), Cell(0,1)], "Steps are never taken back")
        await s.tap(Cell(4,0))
        XCTAssertEqual(s.attempt.mistakes, 1, "A far tap off the route costs a life")
        XCTAssertEqual(s.violation?.kind, .offRoute)
        await s.tap(Cell(1,1))
        XCTAssertEqual(s.attempt.mistakes, 2, "A wrong step beside the tip costs a life")
        XCTAssertEqual(s.attempt.game.path.count, 2)
    }
}

actor ManagedCounter {
    private(set) var value = 0
    func add() { value += 1 }
}

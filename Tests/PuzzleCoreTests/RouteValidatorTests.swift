import XCTest
import Foundation
@testable import PuzzleCore
final class RouteValidatorTests: XCTestCase {
    func testMalformedPaths() throws {
        let p = try PuzzleFixtures.approved.makePuzzle()
        let examples: [([Cell], RuleViolation)] = [
            ([], .wrongStart), ([Cell(1,1)], .wrongStart),
            ([p.start, Cell(-1,0)], .outOfBounds),
            ([p.start, Cell(1,1)], .disconnected),
            ([p.start, Cell(0,1), p.start], .repeatedCell),
            (PuzzleFixtures.approved.witnessRoutes[0] + [Cell(4,3)], .continuedPastGoal)
        ]
        for (path, reason) in examples { XCTAssertEqual(RouteValidator.evaluate(puzzle: p, path: path), .contradiction(reason)) }
    }
    func testObstaclesAndConflictingMarks() throws {
        let p = try PuzzleFixtures.perimeter.makePuzzle()
        XCTAssertEqual(RouteValidator.evaluate(puzzle: p, path: [p.start, Cell(2,2)]), .contradiction(.obstacle))
        for cell in [p.start,p.goal,Cell(2,2),Cell(9,9)] {
            XCTAssertEqual(RouteValidator.evaluate(puzzle: p, path: [p.start], marks: [cell]), .contradiction(.invalidMark))
        }
    }
    func testClueOverflowAndIncompleteAreDistinct() throws {
        let p = try PuzzleFixtures.approved.makePuzzle()
        XCTAssertEqual(RouteValidator.evaluate(puzzle: p, path: [p.start]), .incomplete)
        XCTAssertEqual(RouteValidator.evaluate(puzzle: p, path: [p.start,Cell(1,0)]), .contradiction(.columnExceeded(0)))
        XCTAssertEqual(RouteValidator.evaluate(puzzle: p, path: [p.start,Cell(0,1),Cell(0,2),Cell(0,3)]), .contradiction(.rowExceeded(0)))
        XCTAssertEqual(RouteValidator.counts(puzzle: p, path: [p.start]).rows, [1,0,0,0,1])
    }
    func testBothEdgeArrangementsWinWithoutAnswerComparison() throws {
        let f = PuzzleFixtures.ambiguous
        for path in f.witnessRoutes {
            XCTAssertEqual(RouteValidator.evaluate(puzzle: try f.makePuzzle(), path: path), .complete)
        }
    }
    func testEarlyArrivalCanBeUndoneAndSaved() throws {
        let p = try Puzzle(puzzleID: "early", rows: [2,2], columns: [2,2], start: Cell(0,0), goal: Cell(0,1))
        var game = Game(puzzle: p)
        XCTAssertTrue(game.play(p.goal))
        XCTAssertEqual(game.status, .contradiction(.arrivedBeforeClues))
        game = try JSONDecoder().decode(Game.self, from: JSONEncoder().encode(game))
        XCTAssertEqual(game.status, .contradiction(.arrivedBeforeClues))
        game.undo()
        XCTAssertEqual(game.status, .incomplete)
        for c in [Cell(1,0),Cell(1,1),p.goal] { XCTAssertTrue(game.play(c)) }
        XCTAssertTrue(game.won)
        XCTAssertEqual(game.rowCounts, [2,2])
    }
    func testMismatchedTotalsRejectedAtDefinitionBoundary() {
        XCTAssertThrowsError(try Puzzle(puzzleID: "bad", rows: [2,2], columns: [1,2], start: Cell(0,0), goal: Cell(1,1)))
    }
}

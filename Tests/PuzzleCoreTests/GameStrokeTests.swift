import XCTest
@testable import PuzzleCore
final class GameStrokeTests: XCTestCase {
    func testWholeStrokeIsOneUndoAndRetainsEarlierHistory() {
        var game = Game(); game.play(Cell(0,1))
        var stroke = GameStroke(game: game, marking: false)
        stroke.move(to: Cell(0,2)); stroke.move(to: Cell(1,2)); stroke.move(to: Cell(2,2))
        game = stroke.finish(); XCTAssertEqual(game.path.count, 5)
        game.undo(); XCTAssertEqual(game.path, [Cell(0,0),Cell(0,1)])
        game.undo(); XCTAssertEqual(game.path, [Cell(0,0)])
    }
    func testStepsAreNeverTakenBack() {
        var stroke = GameStroke(game: Game(), marking: false)
        stroke.move(to: Cell(0,1)); stroke.move(to: Cell(0,2))
        stroke.move(to: Cell(0,1)); stroke.move(to: Cell(0,0))
        XCTAssertEqual(stroke.finish().path, [Cell(0,0),Cell(0,1),Cell(0,2)])
        XCTAssertNil(stroke.violation, "Dragging back over the route is ignored, not a mistake")
    }
    func testStepsOffTheSolutionAreMistakes() throws {
        let route = PuzzleFixtures.approved.witnessRoutes[0]
        // Loose clues, so the wrong step breaks nothing visible: only the solution says no.
        let loose = try Puzzle(puzzleID: "loose", rows: [3,3,3], columns: [3,3,3], start: Cell(0,0), goal: Cell(2,2))
        var stroke = GameStroke(game: Game(puzzle: loose), marking: false, solution: [Cell(0,0),Cell(0,1),Cell(1,1),Cell(1,2),Cell(2,2)])
        stroke.move(to: Cell(0,1)); stroke.move(to: Cell(1,1)); stroke.move(to: Cell(2,1))
        XCTAssertEqual(stroke.violation, StrokeViolation(kind: .offRoute, cell: Cell(2,1)))
        XCTAssertEqual(stroke.preview.path, [Cell(0,0),Cell(0,1),Cell(1,1)], "The correct part of the stroke is kept")
        var outside = GameStroke(game: Game(), marking: false, solution: route)
        outside.move(to: Cell(-1,0))
        XCTAssertNil(outside.violation, "Off the board is not a step")
        var marking = GameStroke(game: Game(), marking: true, solution: route)
        marking.move(to: Cell(3,3))
        XCTAssertNil(marking.violation, "× marks are always free")
        XCTAssertEqual(PuzzleSolution.route(for: try PuzzleFixtures.approved.makePuzzle()), route)
    }
    func testMarksToggleOnlyOncePerGesture() {
        var stroke = GameStroke(game: Game(), marking: true)
        for c in [Cell(1,1),Cell(1,1),Cell(2,1),Cell(1,1)] { stroke.move(to: c) }
        var game = stroke.finish()
        XCTAssertEqual(game.marks, [Cell(1,1),Cell(2,1)])
        game.undo(); XCTAssertTrue(game.marks.isEmpty)
    }
    func testCancellationAndInvalidMotion() {
        var stroke = GameStroke(game: Game(), marking: false)
        XCTAssertFalse(stroke.move(to: Cell(1,1)))
        XCTAssertFalse(stroke.move(to: Cell(0,3)))
        XCTAssertTrue(stroke.move(to: Cell(0,1)))
        XCTAssertFalse(stroke.move(to: nil))
        XCTAssertFalse(stroke.move(to: Cell(4,4)))
        XCTAssertEqual(stroke.finish(cancelled: true).path, [Cell(0,0)])
        XCTAssertFalse(stroke.finish(cancelled: true).canUndo)
    }
    func testEndpointsAndMarksCannotOverlap() {
        var stroke = GameStroke(game: Game(), marking: true)
        XCTAssertFalse(stroke.move(to: Cell(0,0)))
        XCTAssertFalse(stroke.move(to: Cell(4,4)))
        stroke.move(to: Cell(0,1))
        var drawing = GameStroke(game: stroke.finish(), marking: false)
        XCTAssertFalse(drawing.move(to: Cell(0,1)))
    }
    func testHitTestingRejectsCluesEdgesAndNonFiniteCoordinates() {
        XCTAssertEqual(BoardHitTest.cell(x: 48, y: 48, side: 48, rows: 5, columns: 5), Cell(0,0))
        XCTAssertEqual(BoardHitTest.cell(x: 287, y: 287, side: 48, rows: 5, columns: 5), Cell(4,4))
        for point in [(0.0,48.0),(48,0),(288,48),(-1,48),(Double.nan,48),(48,Double.infinity)] {
            XCTAssertNil(BoardHitTest.cell(x: point.0, y: point.1, side: 48, rows: 5, columns: 5))
        }
    }
}

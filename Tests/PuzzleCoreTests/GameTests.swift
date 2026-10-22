import XCTest
@testable import PuzzleCore
final class GameTests: XCTestCase {
    func testEndpointsCountBeforeConnection() { XCTAssertEqual(Game().rowCounts, [1,0,0,0,1]) }
    func testVictoryAndUndo() {
        var game = Game()
        for cell in [Cell(0,1),Cell(0,2),Cell(1,2),Cell(2,2),Cell(2,3),Cell(2,4),Cell(3,4),Cell(4,4)] { XCTAssertTrue(game.play(cell)) }
        XCTAssertTrue(game.won)
        game.undo(); XCTAssertFalse(game.won)
    }
    func testRejectsDiagonalAndExceededClue() {
        var game = Game()
        XCTAssertFalse(game.play(Cell(1,1)))
        XCTAssertFalse(game.play(Cell(1,0)))
        XCTAssertEqual(game.path.count, 1)
        XCTAssertFalse(game.canUndo)
    }
    func testMarksAndBacktrack() {
        var game = Game()
        XCTAssertFalse(game.play(game.goal, marking: true))
        XCTAssertTrue(game.play(Cell(0,1), marking: true))
        XCTAssertFalse(game.play(Cell(0,1)))
        game.undo()
        XCTAssertTrue(game.play(Cell(0,1)))
        XCTAssertTrue(game.play(game.start))
        XCTAssertEqual(game.path, [game.start])
    }
}

import XCTest
@testable import PuzzleCore
final class BoardAccessibilityTests: XCTestCase {
    func testCoordinatesCountsAndEndpointsAreAnnounced() {
        let game = Game()
        XCTAssertEqual(BoardAccessibility.label(Cell(0,1)), "Linha 1, coluna 2")
        let start = BoardAccessibility.value(game: game, cell: game.start, dogName: "Lua")
        XCTAssertTrue(start.contains("Lua"))
        XCTAssertTrue(start.contains("Linha: 1 de 3"))
        XCTAssertTrue(start.contains("Coluna: 1 de 1"))
        XCTAssertTrue(start.contains("Ponta atual"))
        let goal = BoardAccessibility.value(game: game, cell: game.goal, dogName: "Lua")
        XCTAssertTrue(goal.contains("ainda não conectada"))
    }
    func testOnlyActualRouteEdgesAreAnnounced() {
        var game = Game()
        game.play(Cell(0,1)); game.play(Cell(0,2))
        let middle = BoardAccessibility.value(game: game, cell: Cell(0,1), dogName: "Lua")
        XCTAssertTrue(middle.contains("Vem de Linha 1, coluna 1"))
        XCTAssertTrue(middle.contains("Segue para Linha 1, coluna 3"))
        XCTAssertFalse(middle.contains("Ponta atual"))
        let tip = BoardAccessibility.value(game: game, cell: Cell(0,2), dogName: "Lua")
        XCTAssertFalse(tip.contains("Segue para"))
        XCTAssertTrue(tip.contains("Ponta atual"))
    }
    func testMarksAndGuidanceAreNotColorOnly() {
        var game = Game(); game.play(Cell(1,0), marking: true)
        let value = BoardAccessibility.value(game: game, cell: Cell(1,0), dogName: "Lua", highlighted: true)
        XCTAssertTrue(value.contains("xis"))
        XCTAssertTrue(value.contains("destacada"))
    }
}

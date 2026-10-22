import XCTest
@testable import PuzzleCore

final class FixtureTests: XCTestCase {
    func testReferenceRoutesRespectEveryRule() {
        for fixture in PuzzleFixtures.all {
            XCTAssertEqual(fixture.rows.count, 5)
            XCTAssertEqual(fixture.columns.count, 5)
            XCTAssertEqual(fixture.rows.reduce(0,+), fixture.columns.reduce(0,+))
            XCTAssertNotEqual(fixture.start, fixture.goal)
            for path in fixture.witnessRoutes {
                XCTAssertEqual(path.first, fixture.start, fixture.id)
                XCTAssertEqual(path.last, fixture.goal, fixture.id)
                XCTAssertEqual(Set(path).count, path.count, fixture.id)
                for cell in path {
                    XCTAssertTrue((0..<5).contains(cell.row) && (0..<5).contains(cell.col))
                    XCTAssertFalse(fixture.obstacles.contains(cell))
                }
                for (a,b) in zip(path, path.dropFirst()) {
                    XCTAssertEqual(abs(a.row-b.row)+abs(a.col-b.col), 1, fixture.id)
                }
                XCTAssertEqual((0..<5).map { r in path.filter { $0.row == r }.count }, fixture.rows)
                XCTAssertEqual((0..<5).map { c in path.filter { $0.col == c }.count }, fixture.columns)
            }
        }
    }
    func testAmbiguityIncludesDifferentEdgesWithSameOccupation() {
        let routes = PuzzleFixtures.ambiguous.witnessRoutes
        XCTAssertEqual(Set(routes[0]), Set(routes[1]))
        XCTAssertNotEqual(routes[0], routes[1])
        XCTAssertEqual(routes[0].first, routes[1].first)
    }
    func testImpossibleFixtureHasNoGeometricConnection() {
        let fixture = PuzzleFixtures.disconnected
        var visited: Set<Cell> = [fixture.start]
        var queue = [fixture.start]
        while let cell = queue.popLast() {
            for next in [Cell(cell.row-1,cell.col),Cell(cell.row+1,cell.col),Cell(cell.row,cell.col-1),Cell(cell.row,cell.col+1)] {
                if (0..<5).contains(next.row), (0..<5).contains(next.col), !fixture.obstacles.contains(next), visited.insert(next).inserted { queue.append(next) }
            }
        }
        XCTAssertFalse(visited.contains(fixture.goal))
    }
    func testApprovedFixtureWinsInCurrentGame() {
        var game = Game()
        for cell in PuzzleFixtures.approved.witnessRoutes[0].dropFirst() { XCTAssertTrue(game.play(cell)) }
        XCTAssertTrue(game.won)
    }
}

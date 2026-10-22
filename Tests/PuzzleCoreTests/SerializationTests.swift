import XCTest
import Foundation
@testable import PuzzleCore
final class SerializationTests: XCTestCase {
    func testRoundTripPreservesUndoAndIdentity() throws {
        var game = Game()
        game.play(Cell(0,1))
        game.play(Cell(3,3), marking: true)
        var restored = try JSONDecoder().decode(Game.self, from: JSONEncoder().encode(game))
        XCTAssertEqual(restored.puzzle, game.puzzle)
        XCTAssertEqual(restored.path, game.path)
        XCTAssertEqual(restored.marks, game.marks)
        restored.undo(); XCTAssertTrue(restored.marks.isEmpty)
        restored.undo(); XCTAssertEqual(restored.path, [game.start])
    }
    func testDecodedDefinitionRejectsUnsupportedVersionAndBounds() throws {
        let data = try JSONEncoder().encode(Game().puzzle)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["schemaVersion"] = 2
        XCTAssertThrowsError(try JSONDecoder().decode(Puzzle.self, from: JSONSerialization.data(withJSONObject: json)))
        json["schemaVersion"] = 1
        json["goal"] = ["row": 50, "col": 0]
        XCTAssertThrowsError(try JSONDecoder().decode(Puzzle.self, from: JSONSerialization.data(withJSONObject: json)))
    }
    func testRejectsDisconnectedSavedRoute() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(Game())) as? [String: Any])
        json["path"] = [["row": 0, "col": 0], ["row": 4, "col": 4]]
        XCTAssertThrowsError(try JSONDecoder().decode(Game.self, from: JSONSerialization.data(withJSONObject: json)))
    }
    func testEveryFixtureCanCreateIndependentGame() throws {
        for fixture in PuzzleFixtures.all {
            var game = Game(puzzle: try fixture.makePuzzle())
            for obstacle in fixture.obstacles {
                XCTAssertFalse(game.play(obstacle, marking: true))
                XCTAssertFalse(game.play(obstacle))
            }
            if let route = fixture.witnessRoutes.first {
                for cell in route.dropFirst() { XCTAssertTrue(game.play(cell)) }
                XCTAssertTrue(game.won)
            }
        }
    }
}

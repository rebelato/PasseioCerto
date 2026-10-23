import XCTest
import Foundation
@testable import PuzzleCore
final class DailyChallengeTests: XCTestCase {
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    func testDayTurnsOverAtLocalMidnight() {
        let brazil = TimeZone(identifier: "America/Sao_Paulo")!
        let evening = DailyChallenge(date: date("2026-10-22T21:00:00-03:00"), timeZone: brazil)
        XCTAssertEqual(evening.id, "daily-v1-2026-10-22")
        XCTAssertEqual(evening, DailyChallenge(date: date("2026-10-22T23:59:59-03:00"), timeZone: brazil))
        let midnight = DailyChallenge(date: date("2026-10-23T00:00:00-03:00"), timeZone: brazil)
        XCTAssertEqual(midnight.id, "daily-v1-2026-10-23")
        XCTAssertEqual(midnight.seed, 20261023)
        XCTAssertEqual(DailyChallenge.nextReset(after: date("2026-10-22T21:00:00-03:00"), timeZone: brazil),
                       date("2026-10-23T00:00:00-03:00"))
    }
    @MainActor func testDailyAndNormalKeepIndependentProgressAcrossRelaunch() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("save.json")
        let s = GameSession(saveURL: url)
        await s.select(Cell(0,1), marking: false)
        let normal = s.attempt.game
        let today = date("2026-10-23T12:00:00Z")
        await s.openDaily(date: today)
        let puzzle = s.attempt.game.puzzle
        XCTAssertEqual(puzzle.puzzleID, DailyChallenge(date: today).id)
        XCTAssertEqual(ExactSolver.solve(puzzle: puzzle).classification, .unique)
        let solution = LogicEngine.analyze(puzzle: puzzle).path
        await s.select(solution[1], marking: false)
        let route = s.attempt.game.path
        s.continueNormal()
        XCTAssertEqual(s.attempt.game.path, normal.path)
        XCTAssertEqual(s.attempt.game.puzzle, normal.puzzle)
        let restored = GameSession(saveURL: url, generate: { _, _ in XCTFail("Persisted daily must not regenerate"); throw CancellationError() })
        await restored.openDaily(date: today)
        XCTAssertEqual(restored.attempt.game.puzzle, puzzle)
        XCTAssertEqual(restored.attempt.game.path, route)
        XCTAssertEqual(GameSession(saveURL: url).activeDailyID, puzzle.puzzleID)
    }
    @MainActor func testClockChangesAndNewNormalDoNotReplaceStoredDaily() async {
        let s = GameSession()
        let today = date("2026-10-23T12:00:00Z")
        let yesterday = date("2026-10-22T12:00:00Z")
        await s.openDaily(date: today)
        let original = s.attempt.game.puzzle
        await s.openDaily(date: yesterday)
        XCTAssertNotEqual(original.puzzleID, s.attempt.game.puzzle.puzzleID)
        await s.newPuzzle(difficulty: .challenging, seed: 2)
        let normal = s.attempt.game.puzzle
        XCTAssertNil(s.activeDailyID)
        await s.openDaily(date: today)
        XCTAssertEqual(s.attempt.game.puzzle, original)
        s.continueNormal()
        XCTAssertEqual(s.attempt.game.puzzle, normal)
    }
    @MainActor func testFailedDailyLeavesNormalUntouched() async {
        struct Failure: Error {}
        let s = GameSession(generate: { _, _ in throw Failure() })
        let original = s.attempt.game.puzzle
        await s.openDaily(date: date("2026-10-23T12:00:00Z"))
        XCTAssertNil(s.activeDailyID)
        XCTAssertTrue(s.parkedAttempts.isEmpty)
        XCTAssertEqual(s.attempt.game.puzzle, original)
    }
    func testMigrationFromV3AndInvalidSlotRejection() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(PlayerSave())) as? [String: Any])
        json["schemaVersion"] = 3
        json.removeValue(forKey: "parkedAttempts")
        let migrated = try JSONDecoder().decode(PlayerSave.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(migrated.schemaVersion, 5)
        XCTAssertNil(migrated.activeDailyID)
        XCTAssertTrue(migrated.parkedAttempts.isEmpty)
        let invalid = PlayerSave(activeDailyID: "daily-v1-2026-10-23")
        XCTAssertThrowsError(try JSONDecoder().decode(PlayerSave.self, from: JSONEncoder().encode(invalid)))
    }
}

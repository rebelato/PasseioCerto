import XCTest
import Foundation
@testable import PuzzleCore
final class SaveStoreTests: XCTestCase {
    private func location() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("save.json") }
    func testRoundTripRestoresAllDataWithoutRegeneration() throws {
        let url = location(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var game = Game(puzzle: PuzzleGenerator.generate(seed: 2).puzzle!)
        game.play(Cell(4,4), marking: true)
        var preferences = PlayerPreferences(); preferences.marking = true; preferences.soundEnabled = false
        let value = PlayerSave(attempt: GameAttempt(game: game), preferences: preferences, tutorialStep: 3, completedPuzzleIDs: ["already-complete"])
        let store = SaveStore(url: url); try store.save(value)
        let loaded = try store.load()
        XCTAssertEqual(loaded.attempt.game.puzzle, game.puzzle)
        XCTAssertEqual(loaded.attempt.game.marks, game.marks)
        XCTAssertEqual(loaded.preferences, preferences)
        XCTAssertEqual(loaded.tutorialStep, 3)
        XCTAssertEqual(loaded.completedPuzzleIDs, ["already-complete"])
    }
    func testInterruptedReplacementKeepsCurrentAndBackupValid() throws {
        let url = location(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = SaveStore(url: url)
        let original = PlayerSave(tutorialStep: 1)
        try store.save(original)
        let bytes = try Data(contentsOf: url)
        let interrupted = SaveStore(url: url) { data, destination in
            if destination == url { throw CocoaError(.fileWriteOutOfSpace) }
            try data.write(to: destination, options: .atomic)
        }
        XCTAssertThrowsError(try interrupted.save(PlayerSave(tutorialStep: 2)))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
        XCTAssertEqual(try store.loadBackup().tutorialStep, 1)
    }
    func testUnknownVersionAndCorruptionCannotBeOverwrittenNormally() throws {
        let url = location(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = SaveStore(url: url); try store.save(PlayerSave())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        json["schemaVersion"] = 99
        let invalid = try JSONSerialization.data(withJSONObject: json)
        try invalid.write(to: url)
        XCTAssertThrowsError(try store.load())
        XCTAssertThrowsError(try store.save(PlayerSave()))
        XCTAssertEqual(try Data(contentsOf: url), invalid)
        try store.recover(PlayerSave(tutorialStep: 4))
        XCTAssertEqual(try store.load().tutorialStep, 4)
        let files = try FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)
        let archive = try XCTUnwrap(files.first { $0.lastPathComponent.contains("preserved-") })
        XCTAssertEqual(try Data(contentsOf: archive), invalid)
    }
    func testMigratesBothOldFormats() throws {
        for bytes in [try JSONEncoder().encode(Game()), try JSONEncoder().encode(GameAttempt())] {
            let loaded = try JSONDecoder().decode(PlayerSave.self, from: bytes)
            XCTAssertEqual(loaded.schemaVersion, 6)
            XCTAssertEqual(loaded.attempt.lives, 3)
            XCTAssertEqual(loaded.preferences, PlayerPreferences())
        }
    }
    func testMigratesV2LivesAndV4CompletedWalks() throws {
        let v2 = Data(#"{"schemaVersion":2,"lives":1,"game":\#(String(decoding: try JSONEncoder().encode(Game()), as: UTF8.self))}"#.utf8)
        let attempt = try JSONDecoder().decode(GameAttempt.self, from: v2)
        XCTAssertEqual(attempt.lives, 1)
        XCTAssertEqual(attempt.mistakes, 2)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(PlayerSave(completedPuzzleIDs: ["a", "b"]))) as? [String: Any])
        json["schemaVersion"] = 4
        json.removeValue(forKey: "bestPaws")
        var preferences = try XCTUnwrap(json["preferences"] as? [String: Any])
        preferences.removeValue(forKey: "difficulty")
        preferences["playMode"] = "relaxed"
        json["preferences"] = preferences
        let save = try JSONDecoder().decode(PlayerSave.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(save.bestPaws, ["a": 1, "b": 1])
        XCTAssertEqual(save.preferences.difficulty, .easy, "Old mode settings fall back to Fácil")
    }
    @MainActor func testSuspendingDiscardsDraftAndPersistsPreferences() async throws {
        let url = location(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let session = GameSession(saveURL: url)
        session.setMarking(true); session.setTutorialStep(2)
        session.begin(at: Cell(1,1), marking: true)
        session.suspend()
        let restored = GameSession(saveURL: url)
        XCTAssertTrue(restored.preferences.marking)
        XCTAssertEqual(restored.tutorialStep, 2)
        XCTAssertTrue(restored.attempt.game.marks.isEmpty)
        XCTAssertEqual(restored.attempt.lives, 3)
    }
    @MainActor func testVictoryRecordedOnceAcrossUndoAndReload() async throws {
        let url = location(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let session = GameSession(saveURL: url)
        for _ in 0..<2 {
            let route = PuzzleFixtures.approved.witnessRoutes[0]
            session.begin(at: route[0], marking: false)
            for cell in route.dropFirst() { session.move(to: cell) }
            await session.finish()
            session.undo()
        }
        XCTAssertEqual(session.completedPuzzleIDs, [PuzzleFixtures.approved.id])
        XCTAssertEqual(GameSession(saveURL: url).completedPuzzleIDs.count, 1)
    }
    @MainActor func testExplicitBackupRecoveryRestoresPreviousSnapshot() async throws {
        let url = location(); defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = SaveStore(url: url)
        try store.save(PlayerSave(tutorialStep: 1))
        try store.save(PlayerSave(tutorialStep: 2))
        let corrupt = Data("broken".utf8); try corrupt.write(to: url)
        let session = GameSession(saveURL: url)
        XCTAssertTrue(session.backupAvailable)
        XCTAssertNotNil(session.storageError)
        session.recoverBackup()
        XCTAssertNil(session.storageError)
        XCTAssertEqual(session.tutorialStep, 1)
        XCTAssertEqual(try store.load().tutorialStep, 1)
    }
}

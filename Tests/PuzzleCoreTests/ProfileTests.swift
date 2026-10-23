import XCTest
import Foundation
@testable import PuzzleCore
final class ProfileTests: XCTestCase {
    func testNamesKeepUnicodeAndHaveSafeFallbackAndLength() {
        XCTAssertEqual(PlayerPreferences.normalizedName(" \n\t "), "Margot")
        XCTAssertEqual(PlayerPreferences.normalizedName("\u{0000}"), "Margot")
        XCTAssertEqual(PlayerPreferences.normalizedName("  M árgot 🐶 & <3  "), "M árgot 🐶 & <3")
        XCTAssertEqual(PlayerPreferences.normalizedName("Lua\nSol"), "Lua Sol")
        let family = "👩‍👩‍👧‍👦"
        let long = PlayerPreferences.normalizedName(String(repeating: family, count: 30))
        XCTAssertEqual(long.count, 24)
        XCTAssertEqual(long, String(repeating: family, count: 24))
    }
    func testExistingPreferencesWithoutNameMigrate() throws {
        let bytes = Data(#"{"marking":true,"soundEnabled":false,"hapticsEnabled":true}"#.utf8)
        let p = try JSONDecoder().decode(PlayerPreferences.self, from: bytes)
        XCTAssertEqual(p.dogName, "Margot")
        XCTAssertTrue(p.marking); XCTAssertFalse(p.soundEnabled); XCTAssertTrue(p.hapticsEnabled)
    }
    @MainActor func testNamePersistsAcrossDailyAndTutorial() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("save.json")
        let s = GameSession(saveURL: url)
        s.renameDog("  Pérola 🐩  ")
        await s.openDaily(date: Date(timeIntervalSince1970: 0))
        let restored = GameSession(saveURL: url)
        XCTAssertEqual(restored.dogName, "Pérola 🐩")
        XCTAssertTrue(TutorialSession(step: 0, dogName: restored.dogName).instruction.contains(restored.dogName))
        restored.continueNormal(); restored.restart()
        XCTAssertNil(restored.message)
        restored.renameDog("")
        XCTAssertEqual(GameSession(saveURL: url).dogName, "Margot")
    }
    @MainActor func testReplayDoesNotDuplicateProgressAndVictoryUsesName() async throws {
        let s = GameSession()
        s.renameDog("Lua")
        for _ in 0..<2 {
            s.restart()
            for cell in PuzzleFixtures.approved.witnessRoutes[0].dropFirst() { await s.select(cell, marking: false) }
            XCTAssertTrue(s.attempt.game.won)
            XCTAssertEqual(s.completedWalkCount, 1)
            XCTAssertNil(s.message)
            s.finishCelebration(); s.suspend()
            XCTAssertEqual(s.completedWalkCount, 1)
        }
        await s.openDaily(date: Date(timeIntervalSince1970: 0))
        let route = LogicEngine.analyze(puzzle: s.attempt.game.puzzle).path
        for cell in route.dropFirst() { await s.select(cell, marking: false) }
        XCTAssertTrue(s.attempt.game.won)
        XCTAssertEqual(s.completedWalkCount, 2)
    }
}

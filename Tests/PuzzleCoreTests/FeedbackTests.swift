import XCTest
import Foundation
@testable import PuzzleCore
final class FeedbackTests: XCTestCase {
    @MainActor func testOneEventPerConfirmedGestureAndNoEventForNoOps() async {
        let s = GameSession()
        await s.select(Cell(1,1), marking: false)
        XCTAssertNil(s.feedback)
        s.begin(at: Cell(0,1), marking: false)
        s.move(to: Cell(0,2))
        XCTAssertNil(s.feedback) // never emit during drag preview
        await s.finish()
        XCTAssertEqual(s.feedback?.kind, .action)
        let first = s.feedback
        await s.select(Cell(0,2), marking: false)
        XCTAssertEqual(s.feedback, first)
        s.undo()
        XCTAssertEqual(s.feedback?.kind, .action)
        XCTAssertNotEqual(s.feedback?.id, first?.id)
    }
    @MainActor func testConflictCancellationAndVictory() async {
        let s = GameSession()
        s.begin(at: Cell(1,0), marking: false)
        await s.finish(cancelled: true)
        XCTAssertNil(s.feedback)
        await s.select(Cell(1,0), marking: false)
        XCTAssertEqual(s.feedback?.kind, .conflict)
        let conflict = s.feedback
        s.restart()
        XCTAssertEqual(s.feedback, conflict)
        s.begin(at: Cell(0,0), marking: false)
        for cell in PuzzleFixtures.approved.witnessRoutes[0].dropFirst() { s.move(to: cell) }
        await s.finish()
        XCTAssertEqual(s.feedback?.kind, .victory)
        let victory = s.feedback
        s.finishCelebration(); s.suspend()
        await s.select(Cell(0,1), marking: false)
        XCTAssertEqual(s.feedback, victory)
    }
    @MainActor func testDisabledPreferencesPersistWithoutLosingProgressOrReplayingFeedback() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("save.json")
        let s = GameSession(saveURL: url)
        await s.select(Cell(0,1), marking: false)
        let route = s.attempt.game.path
        var p = s.preferences; p.soundEnabled = false; p.hapticsEnabled = false
        s.setPreferences(p)
        let restored = GameSession(saveURL: url)
        XCTAssertFalse(restored.preferences.soundEnabled)
        XCTAssertFalse(restored.preferences.hapticsEnabled)
        XCTAssertEqual(restored.attempt.game.path, route)
        XCTAssertNil(restored.feedback)
        await restored.select(Cell(1,1), marking: false)
        XCTAssertTrue(restored.message.contains("perdeu 1 vida"))
        XCTAssertEqual(restored.attempt.lives, 2)
    }
}

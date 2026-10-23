import XCTest
@testable import PuzzleCore
final class WorldTests: XCTestCase {
    func testWorldsGrowAndIntroduceOneRuleEach() {
        XCTAssertEqual(World.allCases.map(\.size), [5, 6, 8, 10, 10])
        XCTAssertEqual(World.allCases.compactMap(\.newRule), ThemedRule.allCases)
        XCTAssertEqual(World.pond.rules, ThemedRule.allCases)
    }
    func testProgressionWalksEveryLevelThenLapsTheLastWorld() {
        var level = WorldLevel.first
        var seen: Set<WorldLevel> = []
        for _ in 0..<(World.allCases.count * World.levelsPerWorld) { XCTAssertTrue(seen.insert(level).inserted); level = level.next }
        XCTAssertEqual(level, WorldLevel(world: .pond, level: 0, round: 1))
        XCTAssertNotEqual(level.seed, WorldLevel(world: .pond, level: 0).seed)
    }
    func testReservesAreCertifiedAndMatchTheirWorld() throws {
        for world in World.allCases {
            let reserves = try XCTUnwrap(FallbackCatalog.worlds[world])
            XCTAssertGreaterThanOrEqual(reserves.count, 2)
            for p in reserves {
                XCTAssertEqual(p.rows.count, world.size)
                XCTAssertEqual(p.columns.count, world.size)
                XCTAssertEqual(LogicEngine.analyze(puzzle: p).outcome, .solved, p.puzzleID)
                XCTAssertEqual(ExactSolver.solve(puzzle: p, nodeLimit: 2_000_000).classification, .unique, p.puzzleID)
                if let rule = world.newRule { XCTAssertTrue(Self.uses(rule, p), "\(p.puzzleID) lacks \(rule)") }
            }
        }
    }
    func testHiddenHouseReservesAndLevelsAreUniqueWithoutKnowingTheEnd() throws {
        for world in World.allCases {
            for p in try XCTUnwrap(FallbackCatalog.hiddenWorlds[world]) {
                XCTAssertTrue(p.hiddenGoal)
                XCTAssertEqual(p.rows.count, world.size)
                XCTAssertEqual(LogicEngine.analyze(puzzle: p).outcome, .solved, p.puzzleID)
                let exact = ExactSolver.solve(puzzle: p, nodeLimit: 2_000_000)
                XCTAssertEqual(exact.classification, .unique, p.puzzleID)
                XCTAssertEqual(exact.solutions.first?.last, p.goal, "The only walk ends at the hidden house")
            }
        }
        let r = WorldGenerator.generate(WorldLevel(world: .beach, level: 1), hiddenHouse: true)
        XCTAssertEqual(r.outcome, .generated)
        XCTAssertEqual(r.puzzle?.hiddenGoal, true)
        XCTAssertNotEqual(r.puzzle, WorldGenerator.generate(WorldLevel(world: .beach, level: 1)).puzzle)
    }
    func testGeneratedLevelsAreVerifiedReproducibleAndThemed() throws {
        for level in [WorldLevel(world: .flowerSquare, level: 0), WorldLevel(world: .beach, level: 2), WorldLevel(world: .market, level: 1)] {
            let a = WorldGenerator.generate(level), b = WorldGenerator.generate(level)
            let p = try XCTUnwrap(a.puzzle)
            XCTAssertEqual(p, b.puzzle)
            XCTAssertEqual(a.outcome, .generated)
            XCTAssertEqual(p.rows.count, level.world.size)
            XCTAssertEqual(LogicEngine.requiredTier(p).map(level.tiers.contains), true)
            XCTAssertEqual(ExactSolver.solve(puzzle: p, nodeLimit: 2_000_000).classification, .unique)
            if let rule = level.world.newRule { XCTAssertTrue(Self.uses(rule, p)) }
        }
    }
    func testExhaustedBudgetFallsBackToTheWorldsReserve() {
        let r = WorldGenerator.generate(WorldLevel(world: .park, level: 2), candidateLimit: 0)
        XCTAssertEqual(r.outcome, .fallback)
        XCTAssertEqual(r.puzzle?.rows.count, 10)
        XCTAssertEqual(WorldGenerator.generate(.first, isCancelled: { true }).outcome, .cancelled)
    }
    private static func uses(_ rule: ThemedRule, _ p: Puzzle) -> Bool {
        switch rule {
        case .bone: !p.bones.isEmpty
        case .tree: !p.trees.isEmpty
        case .cat: !p.cats.isEmpty
        case .puddle: !p.puddles.isEmpty
        }
    }
}

final class ProgressionSessionTests: XCTestCase {
    private static let tiny = try! Puzzle(puzzleID: "tiny", rows: [2,0], columns: [1,1], start: Cell(0,0), goal: Cell(0,1))
    @MainActor func testWinningALevelAdvancesOnceAndFillsTheAlbum() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("save.json")
        let s = GameSession(saveURL: url, generateLevel: { level, _ in
            GenerationReport(outcome: .generated, puzzle: try Self.tiny.renamed("level-\(level.level)", seed: nil), candidates: 1, rejectedBySolver: 0, rejectedByLogic: 0, rejectedByDifficulty: 0)
        })
        await s.play()
        XCTAssertNil(s.attempt.level, "An unfinished free walk is resumed, not replaced")
        for cell in PuzzleFixtures.approved.witnessRoutes[0].dropFirst() { await s.select(cell, marking: false) }
        XCTAssertEqual(s.progress, .first, "Free walks don't move the progression")
        await s.play()
        XCTAssertEqual(s.attempt.level, .first)
        await s.select(Cell(0,1), marking: false)
        XCTAssertTrue(s.attempt.game.won)
        XCTAssertEqual(s.progress, WorldLevel.first.next)
        s.restart(); await s.select(Cell(0,1), marking: false)
        XCTAssertEqual(s.progress, WorldLevel.first.next, "Replaying a level doesn't skip ahead")
        XCTAssertEqual(s.walks.map(\.puzzle.puzzleID), [PuzzleFixtures.approved.id, "level-0"])
        XCTAssertEqual(s.walks.last?.place, .flowerSquare)
        let restored = GameSession(saveURL: url)
        XCTAssertEqual(restored.progress, s.progress)
        XCTAssertEqual(restored.walks, s.walks)
        XCTAssertEqual(restored.attempt.level, .first)
    }
    @MainActor func testChosenLevelsDontMoveProgressAndNextFollowsThem() async {
        let s = GameSession(generateLevel: { level, hidden in
            let id = "level-\(level.world.rawValue)-\(level.level)" + (hidden ? "-hidden" : "")
            return GenerationReport(outcome: .generated, puzzle: try Self.tiny.renamed(id, seed: nil), candidates: 1, rejectedBySolver: 0, rejectedByLogic: 0, rejectedByDifficulty: 0)
        })
        s.setHiddenHouse(true)
        let hardest = WorldLevel(world: .pond, level: World.levelsPerWorld - 1)
        await s.play(hardest)
        XCTAssertEqual(s.attempt.level, hardest)
        XCTAssertEqual(s.attempt.game.puzzle.puzzleID, "level-4-7-hidden")
        await s.select(Cell(0,1), marking: false)
        XCTAssertEqual(s.progress, .first, "Skipping ahead to test a level doesn't move the progression")
        await s.playNext()
        XCTAssertEqual(s.attempt.level, hardest.next)
    }
    @MainActor func testAccessoriesUnlockWithPaws() {
        let s = GameSession()
        XCTAssertTrue(s.unlockedAccessories.isEmpty)
        s.wear(.bow)
        XCTAssertNil(s.preferences.accessory, "Locked accessories can't be worn")
    }
}

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

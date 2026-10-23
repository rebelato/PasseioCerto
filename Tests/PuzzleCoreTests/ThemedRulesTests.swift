import XCTest
@testable import PuzzleCore
final class ThemedRulesTests: XCTestCase {
    /// Straight route along the top of a 3×4 grid, reused by several rules.
    private func puzzle(bones: Set<Cell> = [], trees: Set<Cell> = [], cats: Set<Cell> = [], puddles: Set<Cell> = [], given: [GivenEdge] = []) throws -> Puzzle {
        try Puzzle(puzzleID: "themed", schemaVersion: 2, rows: [4,0,0], columns: [1,1,1,1], start: Cell(0,0), goal: Cell(0,3),
                   bones: bones, trees: trees, cats: cats, puddles: puddles, givenEdges: given)
    }
    private let top = [Cell(0,0),Cell(0,1),Cell(0,2),Cell(0,3)]

    func testValidatorChecksEachRule() throws {
        XCTAssertEqual(RouteValidator.evaluate(puzzle: try puzzle(bones: [Cell(0,2)]), path: top), .complete)
        XCTAssertEqual(RouteValidator.evaluate(puzzle: try puzzle(trees: [Cell(1,1)]), path: top), .complete)
        XCTAssertEqual(RouteValidator.evaluate(puzzle: try puzzle(cats: [Cell(2,1)]), path: top), .complete)
        XCTAssertEqual(RouteValidator.evaluate(puzzle: try puzzle(puddles: [Cell(0,1)]), path: top), .complete)
        XCTAssertEqual(RouteValidator.evaluate(puzzle: try puzzle(given: [GivenEdge(Cell(0,2), Cell(0,1))]), path: top), .complete)

        let detour = try Puzzle(puzzleID: "detour", schemaVersion: 2, rows: [3,2,0], columns: [1,2,2], start: Cell(0,0), goal: Cell(0,2),
                                cats: [], puddles: [Cell(0,1)])
        XCTAssertEqual(RouteValidator.evaluate(puzzle: detour, path: [Cell(0,0),Cell(0,1),Cell(1,1)]), .contradiction(.turnedOnPuddle))
        let catPuzzle = try Puzzle(puzzleID: "cat", schemaVersion: 2, rows: [3,0,0], columns: [1,1,1], start: Cell(0,0), goal: Cell(0,2), cats: [Cell(2,0)])
        XCTAssertEqual(RouteValidator.evaluate(puzzle: catPuzzle, path: [Cell(0,0),Cell(1,0)]), .contradiction(.nearCat))
        XCTAssertEqual(RouteValidator.evaluate(puzzle: try puzzle(given: [GivenEdge(Cell(0,1), Cell(1,1))]), path: [Cell(0,0),Cell(0,1),Cell(0,2)]),
                       .contradiction(.brokeGivenEdge))
        XCTAssertThrowsError(try puzzle(cats: [Cell(1,0)]), "A cat beside the start is not a valid puzzle")
    }
    func testUnmetStopsAreAnEarlyArrival() throws {
        let p = try Puzzle(puzzleID: "bone", schemaVersion: 2, rows: [2,2], columns: [2,2], start: Cell(0,0), goal: Cell(0,1), bones: [Cell(1,1)])
        XCTAssertEqual(RouteValidator.evaluate(puzzle: p, path: [Cell(0,0),Cell(0,1)]), .contradiction(.arrivedBeforeClues))
        XCTAssertEqual(RouteValidator.evaluate(puzzle: p, path: [Cell(0,0),Cell(1,0),Cell(1,1),Cell(0,1)]), .complete)
    }
    func testStrokesFlagThemedMistakes() throws {
        let catPuzzle = try Puzzle(puzzleID: "cat", schemaVersion: 2, rows: [3,0,0], columns: [1,1,1], start: Cell(0,0), goal: Cell(0,2), cats: [Cell(2,0)])
        var near = GameStroke(game: Game(puzzle: catPuzzle), marking: false)
        near.move(to: Cell(1,0))
        XCTAssertEqual(near.violation?.kind, .nearCat)
        let p = try Puzzle(puzzleID: "puddle", schemaVersion: 2, rows: [2,2,0], columns: [1,2,1], start: Cell(0,0), goal: Cell(1,2), puddles: [Cell(0,1)])
        var turn = GameStroke(game: Game(puzzle: p), marking: false)
        turn.move(to: Cell(0,1)); turn.move(to: Cell(1,1))
        XCTAssertEqual(turn.violation?.kind, .puddleTurn)
        XCTAssertEqual(turn.violation?.cell, Cell(0,1))
    }
    func testThemedPuzzlesRoundTripAndPlainOnesKeepTheirShape() throws {
        let p = try puzzle(bones: [Cell(0,2)], given: [GivenEdge(Cell(0,0), Cell(0,1))])
        XCTAssertEqual(try JSONDecoder().decode(Puzzle.self, from: JSONEncoder().encode(p)), p)
        let plain = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Game().puzzle)) as? [String: Any]
        XCTAssertNil(plain?["bones"])
        XCTAssertNil(plain?["givenEdges"])
    }
    func testLogicDeducesFromEachRule() throws {
        let cat = try Puzzle(puzzleID: "cat", schemaVersion: 2, rows: [3,0,0], columns: [1,1,1], start: Cell(0,0), goal: Cell(0,2), cats: [Cell(2,0)])
        XCTAssertTrue(LogicEngine.analyze(puzzle: cat).deductions.contains { $0.reason == .catNearby })
        // Only one free cell beside the tree.
        let tree = try Puzzle(puzzleID: "tree", schemaVersion: 2, rows: [2,2,1], columns: [1,2,2], start: Cell(0,0), goal: Cell(2,2),
                              obstacles: [Cell(2,0)], trees: [Cell(1,0)])
        let solved = LogicEngine.analyze(puzzle: tree)
        XCTAssertEqual(solved.outcome, .solved)
        XCTAssertEqual(ExactSolver.solve(puzzle: tree).classification, .unique)
        XCTAssertEqual(LogicEngine.requiredTier(try puzzle()), 2, "Extending the route always needs continuation")
    }

    /// Exhaustive check: on small grids with random rules, the pruned solver agrees with brute force.
    func testSolverMatchesBruteForceWithRules() throws {
        var state: UInt64 = 7
        func random(_ bound: Int) -> Int { state = state &* 6364136223846793005 &+ 1442695040888963407; return Int((state >> 33) % UInt64(bound)) }
        let n = 4
        let cells = (0..<n).flatMap { r in (0..<n).map { Cell(r, $0) } }
        var checked = 0
        for _ in 0..<60 {
            let start = cells[random(cells.count)]
            var goal = cells[random(cells.count)]
            while goal == start { goal = cells[random(cells.count)] }
            var routes: [[Cell]] = []
            func enumerate(_ path: [Cell]) {
                let last = path.last!
                if last == goal { routes.append(path); return }
                for next in Cell.neighbors(last) where (0..<n).contains(next.row) && (0..<n).contains(next.col) && !path.contains(next) { enumerate(path + [next]) }
            }
            enumerate([start])
            guard let witness = routes.randomElement(using: &SeededGenerator.shared) else { continue }
            let onRoute = Set(witness)
            let free = cells.filter { !onRoute.contains($0) }
            let interior = Array(witness.dropFirst().dropLast())
            let straight = witness.indices.dropFirst().dropLast().filter { witness[$0-1].row == witness[$0+1].row || witness[$0-1].col == witness[$0+1].col }.map { witness[$0] }
            let bones: Set<Cell> = interior.isEmpty || random(2) == 0 ? [] : [interior[random(interior.count)]]
            let puddles: Set<Cell> = Set(straight.filter { !bones.contains($0) }.prefix(random(2)))
            let trees: Set<Cell> = free.isEmpty || random(2) == 0 ? [] : [free[random(free.count)]]
            let lonely = free.filter { c in !trees.contains(c) && Cell.neighbors(c).allSatisfy { !onRoute.contains($0) } }
            let cats: Set<Cell> = lonely.isEmpty || random(2) == 0 ? [] : [lonely[random(lonely.count)]]
            let given: [GivenEdge] = witness.count > 2 && random(2) == 0 ? [GivenEdge(witness[1], witness[2])] : []
            let rows = (0..<n).map { r in witness.filter { $0.row == r }.count }
            let columns = (0..<n).map { c in witness.filter { $0.col == c }.count }
            guard let p = try? Puzzle(puzzleID: "brute", schemaVersion: 2, rows: rows, columns: columns, start: start, goal: goal,
                                      bones: bones, trees: trees, cats: cats, puddles: puddles, givenEdges: given) else { continue }
            let valid = routes.filter { RouteValidator.evaluate(puzzle: p, path: $0) == .complete }
            let result = ExactSolver.solve(puzzle: p, nodeLimit: 1_000_000)
            XCTAssertEqual(result.classification, valid.isEmpty ? .noSolution : valid.count == 1 ? .unique : .multiple, "\(p)")
            for route in result.solutions { XCTAssertTrue(valid.contains(route)) }
            if LogicEngine.analyze(puzzle: p).outcome == .solved { XCTAssertEqual(valid.count, 1, "Logic must never solve an ambiguous grid") }
            checked += 1
        }
        XCTAssertGreaterThan(checked, 40)
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    nonisolated(unsafe) static var shared = SeededGenerator()
    var state: UInt64 = 42
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
}

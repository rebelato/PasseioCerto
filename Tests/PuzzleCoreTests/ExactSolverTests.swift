import XCTest
@testable import PuzzleCore
final class ExactSolverTests: XCTestCase {
    func testFixtures() throws {
        for (fixture, expected) in [(PuzzleFixtures.approved, SolverClassification.unique), (PuzzleFixtures.perimeter, SolverClassification.unique), (PuzzleFixtures.disconnected, SolverClassification.noSolution), (PuzzleFixtures.ambiguous, SolverClassification.multiple)] {
            let p = try fixture.makePuzzle()
            let result = ExactSolver.solve(puzzle: p)
            XCTAssertEqual(result.classification, expected, fixture.id)
            for path in result.solutions { XCTAssertEqual(RouteValidator.evaluate(puzzle: p, path: path), .complete) }
            XCTAssertLessThanOrEqual(result.solutions.count, 2)
        }
    }
    func testConstraintsAndMalformedPrefix() throws {
        let p = try PuzzleFixtures.approved.makePuzzle()
        XCTAssertEqual(ExactSolver.solve(puzzle: p, prefix: [p.start,Cell(0,1)]).classification, .unique)
        XCTAssertEqual(ExactSolver.solve(puzzle: p, excluding: [Cell(0,1)]).classification, .noSolution)
        XCTAssertEqual(ExactSolver.solve(puzzle: p, prefix: []).classification, .noSolution)
        XCTAssertEqual(ExactSolver.solve(puzzle: p, prefix: [p.start,p.goal]).classification, .noSolution)
    }
    func testBudgetsCancellationAndDeterminism() throws {
        let p = try PuzzleFixtures.ambiguous.makePuzzle()
        XCTAssertEqual(ExactSolver.solve(puzzle: p, nodeLimit: 0).classification, .indeterminate)
        XCTAssertEqual(ExactSolver.solve(puzzle: p, isCancelled: { true }).visitedNodes, 0)
        var checks = 0
        let cancelled = ExactSolver.solve(puzzle: p, isCancelled: { checks += 1; return checks > 4 })
        XCTAssertEqual(cancelled.classification, .indeterminate)
        XCTAssertEqual(cancelled.visitedNodes, 4)
        let a = ExactSolver.solve(puzzle: p)
        let b = ExactSolver.solve(puzzle: p)
        XCTAssertEqual(a.solutions, b.solutions)
        XCTAssertEqual(a.visitedNodes, b.visitedNodes)
        // Exhausting a budget after finding one witness cannot certify uniqueness.
        var foundPartial = false
        for budget in 1..<a.visitedNodes {
            let r = ExactSolver.solve(puzzle: p, nodeLimit: budget)
            if r.solutions.count == 1 {
                foundPartial = true
                XCTAssertEqual(r.classification, .indeterminate)
                break
            }
        }
        XCTAssertTrue(foundPartial)
    }
    func testAgainstIndependentSmallGridEnumeration() throws {
        // Enumerate ALL simple 3x3 routes without validator or clue pruning,
        // then independently group by row/column clues for every destination.
        let start = Cell(0,0)
        for goal in (0..<9).dropFirst().map({ Cell($0/3,$0%3) }) {
            var routes: [[Cell]] = []
            func enumerate(_ path: [Cell]) {
                let last = path.last!
                if last == goal { routes.append(path); return }
                for r in 0..<3 { for c in 0..<3 {
                    let next = Cell(r,c)
                    if !path.contains(next), abs(r-last.row)+abs(c-last.col) == 1 { enumerate(path+[next]) }
                } }
            }
            enumerate([start])
            func clues(_ path: [Cell]) -> [Int] {
                (0..<3).map { r in path.filter { $0.row == r }.count } + (0..<3).map { c in path.filter { $0.col == c }.count }
            }
            let groups = Dictionary(grouping: routes, by: clues)
            for (key, witnesses) in groups {
                let p = try Puzzle(puzzleID: "enumeration", rows: Array(key.prefix(3)), columns: Array(key.suffix(3)), start: start, goal: goal)
                let result = ExactSolver.solve(puzzle: p)
                XCTAssertEqual(result.classification, witnesses.count == 1 ? .unique : .multiple)
                for route in result.solutions { XCTAssertTrue(witnesses.contains(route)) }
                // Repeat with each possible excluded cell to include impossible cases.
                for index in 1..<9 where Cell(index/3,index%3) != goal {
                    let blocked = Cell(index/3,index%3)
                    let count = witnesses.filter { !$0.contains(blocked) }.count
                    XCTAssertEqual(ExactSolver.solve(puzzle: p, excluding: [blocked]).classification, count == 0 ? .noSolution : count == 1 ? .unique : .multiple)
                }
            }
        }
    }
}

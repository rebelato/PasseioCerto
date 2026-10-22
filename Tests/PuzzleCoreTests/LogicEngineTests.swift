import XCTest
@testable import PuzzleCore
final class LogicEngineTests: XCTestCase {
    func testApprovedAndPerimeterSolvedWithExplanations() throws {
        for f in [PuzzleFixtures.approved, PuzzleFixtures.perimeter] {
            let p = try f.makePuzzle()
            let r = LogicEngine.analyze(puzzle: p)
            XCTAssertEqual(r.outcome, .solved)
            XCTAssertEqual(RouteValidator.evaluate(puzzle: p, path: r.path), .complete)
            XCTAssertFalse(r.deductions.isEmpty)
            XCTAssertTrue(r.deductions.allSatisfy { !$0.explanation.isEmpty })
        }
    }
    func testAmbiguousStallsWithoutInventingConnections() throws {
        let r = LogicEngine.analyze(puzzle: try PuzzleFixtures.ambiguous.makePuzzle())
        XCTAssertEqual(r.outcome, .stalled)
        XCTAssertEqual(r.path, [Cell(0,0)])
        XCTAssertTrue(r.deductions.contains { $0.action == .required(Cell(2,1)) })
    }
    func testConflictsAndPlayerAssumptions() throws {
        let p = try PuzzleFixtures.approved.makePuzzle()
        let r = LogicEngine.analyze(puzzle: p, marks: [Cell(0,1)])
        guard case .contradiction = r.outcome else { return XCTFail("Expected conflict") }
        XCTAssertEqual(r.assumedMarks, [Cell(0,1)])
        let blocked = LogicEngine.analyze(puzzle: try PuzzleFixtures.disconnected.makePuzzle())
        guard case .contradiction = blocked.outcome else { return XCTFail("Expected disconnected conflict") }
    }
    func testEveryDeductionHoldsForAllIndependentSmallGridSolutions() throws {
        let start = Cell(0,0)
        for goalIndex in 1..<9 {
            let goal = Cell(goalIndex/3,goalIndex%3)
            var routes: [[Cell]] = []
            func walk(_ path: [Cell]) {
                let end = path.last!
                if end == goal { routes.append(path); return }
                for i in 0..<9 {
                    let n = Cell(i/3,i%3)
                    if !path.contains(n), abs(n.row-end.row)+abs(n.col-end.col) == 1 { walk(path+[n]) }
                }
            }
            walk([start])
            let groups = Dictionary(grouping: routes) { path in
                (0..<3).map { r in path.filter { $0.row == r }.count } + (0..<3).map { c in path.filter { $0.col == c }.count }
            }
            for (clues, solutions) in groups {
                let p = try Puzzle(puzzleID: "logic-test", rows: Array(clues.prefix(3)), columns: Array(clues.suffix(3)), start: start, goal: goal)
                // Include real partial paths, with and without compatible player marks.
                for witness in solutions {
                    let prefix = Array(witness.prefix(min(2,witness.count)))
                    let marks: Set<Cell> = Set((0..<9).map { Cell($0/3,$0%3) }).subtracting(witness)
                    for excluded in [Set<Cell>(),marks] {
                        let compatible = solutions.filter { Array($0.prefix(prefix.count)) == prefix && Set($0).isDisjoint(with: excluded) }
                        let result = LogicEngine.analyze(puzzle: p, prefix: prefix, marks: excluded)
                        if case .contradiction = result.outcome { XCTFail("Rejected valid state"); continue }
                        var extended = prefix
                        for d in result.deductions {
                            switch d.action {
                            case .required(let c): XCTAssertTrue(compatible.allSatisfy { $0.contains(c) })
                            case .excluded(let c): XCTAssertTrue(compatible.allSatisfy { !$0.contains(c) })
                            case .extend(let c):
                                extended.append(c)
                                XCTAssertTrue(compatible.allSatisfy { Array($0.prefix(extended.count)) == extended })
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Reference data for rules, previews and future solver regression tests.
/// Expected classifications are evidence-backed; production solver verification is PC-005.
public struct PuzzleFixture: Sendable {
    public enum Expectation: Sendable { case solvable, impossible, multiple }
    public let id: String
    public let rows: [Int]
    public let columns: [Int]
    public let start: Cell
    public let goal: Cell
    public let obstacles: Set<Cell>
    public let expectation: Expectation
    public let witnessRoutes: [[Cell]]
}

public enum PuzzleFixtures {
    public static let approved = PuzzleFixture(
        id: "approved-5x5-v1", rows: [3,1,3,1,1], columns: [1,1,3,1,3],
        start: Cell(0,0), goal: Cell(4,4), obstacles: [], expectation: .solvable,
        witnessRoutes: [[Cell(0,0),Cell(0,1),Cell(0,2),Cell(1,2),Cell(2,2),Cell(2,3),Cell(2,4),Cell(3,4),Cell(4,4)]])

    public static let perimeter = PuzzleFixture(
        id: "perimeter-5x5-v1", rows: [5,1,1,1,1], columns: [1,1,1,1,5],
        start: Cell(0,0), goal: Cell(4,4), obstacles: [Cell(2,2)], expectation: .solvable,
        witnessRoutes: [[Cell(0,0),Cell(0,1),Cell(0,2),Cell(0,3),Cell(0,4),Cell(1,4),Cell(2,4),Cell(3,4),Cell(4,4)]])

    // Equal clue totals and valid endpoints, but a full blocked row separates them.
    public static let disconnected = PuzzleFixture(
        id: "disconnected-5x5-v1", rows: [3,1,0,2,3], columns: [1,1,3,1,3],
        start: Cell(0,0), goal: Cell(4,4), obstacles: Set((0..<5).map { Cell(2,$0) }),
        expectation: .impossible, witnessRoutes: [])

    // Both routes occupy the SAME cells. Their explicit edges differ.
    public static let ambiguous = PuzzleFixture(
        id: "ambiguous-5x5-v1", rows: [3,3,3,0,0], columns: [3,3,3,0,0],
        start: Cell(0,0), goal: Cell(2,2), obstacles: [], expectation: .multiple,
        witnessRoutes: [
            [Cell(0,0),Cell(1,0),Cell(2,0),Cell(2,1),Cell(1,1),Cell(0,1),Cell(0,2),Cell(1,2),Cell(2,2)],
            [Cell(0,0),Cell(0,1),Cell(0,2),Cell(1,2),Cell(1,1),Cell(1,0),Cell(2,0),Cell(2,1),Cell(2,2)]
        ])
    public static let all = [approved, perimeter, disconnected, ambiguous]
}

import Foundation

public enum PuzzleError: Error { case invalidDefinition, invalidSession }

/// Immutable, versioned definition. Decoding applies the same validation as creation.
public struct Puzzle: Codable, Equatable, Sendable {
    public let puzzleID: String
    public let schemaVersion: Int
    public let generatorVersion: Int
    public let seed: UInt64?
    public let rows: [Int]
    public let columns: [Int]
    public let start: Cell
    public let goal: Cell
    public let obstacles: Set<Cell>

    public init(puzzleID: String, schemaVersion: Int = 1, generatorVersion: Int = 1, seed: UInt64? = nil, rows: [Int], columns: [Int], start: Cell, goal: Cell, obstacles: Set<Cell> = []) throws {
        self.puzzleID = puzzleID; self.schemaVersion = schemaVersion
        self.generatorVersion = generatorVersion; self.seed = seed
        self.rows = rows; self.columns = columns
        self.start = start; self.goal = goal; self.obstacles = obstacles
        guard !puzzleID.isEmpty, schemaVersion == 1, generatorVersion > 0,
              (2...7).contains(rows.count), (2...7).contains(columns.count),
              rows.allSatisfy({ (0...columns.count).contains($0) }),
              columns.allSatisfy({ (0...rows.count).contains($0) }),
              rows.reduce(0,+) == columns.reduce(0,+), start != goal,
              contains(start), contains(goal), obstacles.allSatisfy(contains),
              !obstacles.contains(start), !obstacles.contains(goal) else { throw PuzzleError.invalidDefinition }
        for cell in [start, goal] {
            guard rows[cell.row] >= [start,goal].filter({ $0.row == cell.row }).count,
                  columns[cell.col] >= [start,goal].filter({ $0.col == cell.col }).count else { throw PuzzleError.invalidDefinition }
        }
    }
    public func contains(_ cell: Cell) -> Bool { rows.indices.contains(cell.row) && columns.indices.contains(cell.col) }
    private enum CodingKeys: String, CodingKey { case puzzleID, schemaVersion, generatorVersion, seed, rows, columns, start, goal, obstacles }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(puzzleID: c.decode(String.self, forKey: .puzzleID), schemaVersion: c.decode(Int.self, forKey: .schemaVersion), generatorVersion: c.decode(Int.self, forKey: .generatorVersion), seed: c.decodeIfPresent(UInt64.self, forKey: .seed), rows: c.decode([Int].self, forKey: .rows), columns: c.decode([Int].self, forKey: .columns), start: c.decode(Cell.self, forKey: .start), goal: c.decode(Cell.self, forKey: .goal), obstacles: c.decode(Set<Cell>.self, forKey: .obstacles))
    }
}

public extension PuzzleFixture {
    func makePuzzle() throws -> Puzzle {
        try Puzzle(puzzleID: id, rows: rows, columns: columns, start: start, goal: goal, obstacles: obstacles)
    }
}

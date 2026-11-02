import Foundation

public enum PuzzleError: Error { case invalidDefinition, invalidSession }

/// A pre-drawn piece of route: the two cells must be consecutive in the solution.
public struct GivenEdge: Hashable, Codable, Sendable {
    public let a: Cell
    public let b: Cell
    public init(_ a: Cell, _ b: Cell) { self.a = a; self.b = b }
    public func partner(of cell: Cell) -> Cell? { cell == a ? b : cell == b ? a : nil }
}

/// Immutable, versioned definition. Decoding applies the same validation as creation.
/// Themed rules (schema 2) are optional, so schema 1 puzzles decode unchanged:
/// - bones: the route must pass through them;
/// - trees: block their cell, and the route must pass beside each one;
/// - cats: block their cell, and the route may not pass beside them;
/// - puddles: the route may cross them, but only in a straight line;
/// - givenEdges: pre-drawn route pieces.
public struct Puzzle: Codable, Equatable, Sendable {
    public static let sizes = 2...10
    public let puzzleID: String
    public let schemaVersion: Int
    public let generatorVersion: Int
    public let seed: UInt64?
    public let rows: [Int]
    public let columns: [Int]
    public let start: Cell
    public let goal: Cell
    public let obstacles: Set<Cell>
    public let bones: Set<Cell>
    public let trees: Set<Cell>
    public let cats: Set<Cell>
    public let puddles: Set<Cell>
    public let givenEdges: [GivenEdge]
    /// Cells the route can never use: shrubs, trees and cats.
    public let blocked: Set<Cell>
    /// Free cells beside a cat; stepping there breaks the cat rule.
    public let catZone: Set<Cell>

    public init(puzzleID: String, schemaVersion: Int = 1, generatorVersion: Int = 1, seed: UInt64? = nil, rows: [Int], columns: [Int], start: Cell, goal: Cell, obstacles: Set<Cell> = [],
                bones: Set<Cell> = [], trees: Set<Cell> = [], cats: Set<Cell> = [], puddles: Set<Cell> = [], givenEdges: [GivenEdge] = []) throws {
        self.puzzleID = puzzleID; self.schemaVersion = schemaVersion
        self.generatorVersion = generatorVersion; self.seed = seed
        self.rows = rows; self.columns = columns
        self.start = start; self.goal = goal; self.obstacles = obstacles
        self.bones = bones; self.trees = trees; self.cats = cats; self.puddles = puddles; self.givenEdges = givenEdges
        blocked = obstacles.union(trees).union(cats)
        let inside = { (c: Cell) in rows.indices.contains(c.row) && columns.indices.contains(c.col) }
        catZone = Set(cats.flatMap(Cell.neighbors).filter(inside)).subtracting(obstacles.union(trees).union(cats))
        let endpoints: Set<Cell> = [start, goal]
        guard !puzzleID.isEmpty, (1...2).contains(schemaVersion), generatorVersion > 0,
              Self.sizes.contains(rows.count), Self.sizes.contains(columns.count),
              rows.allSatisfy({ (0...columns.count).contains($0) }),
              columns.allSatisfy({ (0...rows.count).contains($0) }),
              rows.reduce(0,+) == columns.reduce(0,+), start != goal,
              contains(start), contains(goal),
              [obstacles, bones, trees, cats, puddles].allSatisfy({ $0.allSatisfy(contains) }),
              blocked.isDisjoint(with: endpoints), catZone.isDisjoint(with: endpoints),
              obstacles.isDisjoint(with: trees.union(cats)), trees.isDisjoint(with: cats),
              bones.union(puddles).isDisjoint(with: blocked.union(catZone)), bones.isDisjoint(with: puddles),
              puddles.isDisjoint(with: endpoints),
              givenEdges.allSatisfy({ contains($0.a) && contains($0.b) && $0.a.isAdjacent(to: $0.b)
                  && blocked.union(catZone).isDisjoint(with: [$0.a, $0.b]) }) else { throw PuzzleError.invalidDefinition }
        for cell in [start, goal] {
            guard rows[cell.row] >= [start,goal].filter({ $0.row == cell.row }).count,
                  columns[cell.col] >= [start,goal].filter({ $0.col == cell.col }).count else { throw PuzzleError.invalidDefinition }
        }
    }
    public func contains(_ cell: Cell) -> Bool { rows.indices.contains(cell.row) && columns.indices.contains(cell.col) }
    public func neighbors(_ cell: Cell) -> [Cell] { Cell.neighbors(cell).filter(contains) }
    /// Any themed rule beyond clues and shrubs.
    public var hasThemedRules: Bool { !(bones.isEmpty && trees.isEmpty && cats.isEmpty && puddles.isEmpty && givenEdges.isEmpty) }
    private enum CodingKeys: String, CodingKey { case puzzleID, schemaVersion, generatorVersion, seed, rows, columns, start, goal, obstacles, bones, trees, cats, puddles, givenEdges }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(puzzleID: c.decode(String.self, forKey: .puzzleID), schemaVersion: c.decode(Int.self, forKey: .schemaVersion), generatorVersion: c.decode(Int.self, forKey: .generatorVersion), seed: c.decodeIfPresent(UInt64.self, forKey: .seed), rows: c.decode([Int].self, forKey: .rows), columns: c.decode([Int].self, forKey: .columns), start: c.decode(Cell.self, forKey: .start), goal: c.decode(Cell.self, forKey: .goal), obstacles: c.decode(Set<Cell>.self, forKey: .obstacles),
            bones: c.decodeIfPresent(Set<Cell>.self, forKey: .bones) ?? [], trees: c.decodeIfPresent(Set<Cell>.self, forKey: .trees) ?? [],
            cats: c.decodeIfPresent(Set<Cell>.self, forKey: .cats) ?? [], puddles: c.decodeIfPresent(Set<Cell>.self, forKey: .puddles) ?? [],
            givenEdges: c.decodeIfPresent([GivenEdge].self, forKey: .givenEdges) ?? [])
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(puzzleID, forKey: .puzzleID); try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(generatorVersion, forKey: .generatorVersion); try c.encodeIfPresent(seed, forKey: .seed)
        try c.encode(rows, forKey: .rows); try c.encode(columns, forKey: .columns)
        try c.encode(start, forKey: .start); try c.encode(goal, forKey: .goal); try c.encode(obstacles, forKey: .obstacles)
        // Schema 1 puzzles keep their original shape on disk.
        if !bones.isEmpty { try c.encode(bones, forKey: .bones) }
        if !trees.isEmpty { try c.encode(trees, forKey: .trees) }
        if !cats.isEmpty { try c.encode(cats, forKey: .cats) }
        if !puddles.isEmpty { try c.encode(puddles, forKey: .puddles) }
        if !givenEdges.isEmpty { try c.encode(givenEdges, forKey: .givenEdges) }
    }
    /// Same grid under another identity (daily challenges reuse generated grids).
    public func renamed(_ id: String, seed: UInt64?) throws -> Puzzle {
        try Puzzle(puzzleID: id, schemaVersion: schemaVersion, generatorVersion: generatorVersion, seed: seed, rows: rows, columns: columns, start: start, goal: goal, obstacles: obstacles,
                   bones: bones, trees: trees, cats: cats, puddles: puddles, givenEdges: givenEdges)
    }
}

public extension PuzzleFixture {
    func makePuzzle() throws -> Puzzle {
        try Puzzle(puzzleID: id, rows: rows, columns: columns, start: start, goal: goal, obstacles: obstacles)
    }
}

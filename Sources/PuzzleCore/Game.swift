public struct Cell: Hashable, Codable, Sendable {
    public let row: Int
    public let col: Int
    public init(_ row: Int, _ col: Int) { self.row = row; self.col = col }
    /// Up, right, down, left: fixed order keeps searches reproducible.
    public static func neighbors(_ c: Cell) -> [Cell] { [Cell(c.row-1,c.col),Cell(c.row,c.col+1),Cell(c.row+1,c.col),Cell(c.row,c.col-1)] }
    public func isAdjacent(to other: Cell) -> Bool { abs(row-other.row)+abs(col-other.col) == 1 }
}
public struct Game: Codable, Sendable {
    public let puzzle: Puzzle
    public var rows: [Int] { puzzle.rows }
    public var columns: [Int] { puzzle.columns }
    public var start: Cell { puzzle.start }
    public var goal: Cell { puzzle.goal }
    public private(set) var path: [Cell]
    public private(set) var marks: Set<Cell> = []
    private struct Snapshot: Codable, Sendable { let path: [Cell]; let marks: Set<Cell> }
    private var history: [Snapshot] = []
    public init(puzzle: Puzzle) { self.puzzle = puzzle; path = [puzzle.start] }
    public init() { self.init(puzzle: try! PuzzleFixtures.approved.makePuzzle()) }
    public var occupied: Set<Cell> { Set(path).union(puzzle.knownGoal.map { [$0] } ?? []) }
    public var rowCounts: [Int] { RouteValidator.counts(puzzle: puzzle, path: path).rows }
    public var columnCounts: [Int] { RouteValidator.counts(puzzle: puzzle, path: path).columns }
    public var status: RouteStatus { RouteValidator.evaluate(puzzle: puzzle, path: path, marks: marks) }
    public var won: Bool { status == .complete }
    public var canUndo: Bool { !history.isEmpty }
    @discardableResult public mutating func play(_ cell: Cell, marking: Bool = false) -> Bool {
        guard puzzle.contains(cell), !puzzle.blocked.contains(cell), !won else { return false }
        let previous = Snapshot(path: path, marks: marks)
        if marking {
            guard !occupied.contains(cell) else { return false }
            if !marks.insert(cell).inserted { marks.remove(cell) }
        } else {
            if path.count > 1 && path[path.count - 2] == cell { path.removeLast() }
            else {
                guard let last = path.last, last != puzzle.knownGoal, !path.contains(cell), !marks.contains(cell), abs(last.row-cell.row)+abs(last.col-cell.col) == 1 else { return false }
                path.append(cell)
                if case .contradiction(let violation) = RouteValidator.evaluate(puzzle: puzzle, path: path), violation != .arrivedBeforeClues {
                    path = previous.path; return false
                }
            }
        }
        history.append(previous)
        return true
    }
    public mutating func undo() { if let state = history.popLast() { path = state.path; marks = state.marks } }
}

extension Game {
    private enum CodingKeys: String, CodingKey { case puzzle, path, marks, history }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        puzzle = try c.decode(Puzzle.self, forKey: .puzzle)
        path = try c.decode([Cell].self, forKey: .path)
        marks = try c.decode(Set<Cell>.self, forKey: .marks)
        history = try c.decode([Snapshot].self, forKey: .history)
        guard valid(path, marks), history.allSatisfy({ valid($0.path, $0.marks) }) else { throw PuzzleError.invalidSession }
    }
    private func valid(_ route: [Cell], _ excluded: Set<Cell>) -> Bool {
        switch RouteValidator.evaluate(puzzle: puzzle, path: route, marks: excluded) {
        case .incomplete, .complete, .contradiction(.arrivedBeforeClues): return true
        default: return false
        }
    }
}

extension Game {
    mutating func commitStroke(_ draft: Game) {
        guard puzzle == draft.puzzle, valid(draft.path, draft.marks), path != draft.path || marks != draft.marks else { return }
        history.append(Snapshot(path: path, marks: marks))
        path = draft.path
        marks = draft.marks
    }
    mutating func discardStrokeHistory() { history.removeAll(keepingCapacity: true) }
}

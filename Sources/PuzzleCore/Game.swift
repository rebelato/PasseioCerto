public struct Cell: Hashable, Sendable {
    public let row: Int
    public let col: Int
    public init(_ row: Int, _ col: Int) { self.row = row; self.col = col }
}
public struct Game: Sendable {
    public let rows = PuzzleFixtures.approved.rows
    public let columns = PuzzleFixtures.approved.columns
    public let start = PuzzleFixtures.approved.start
    public let goal = PuzzleFixtures.approved.goal
    public private(set) var path = [PuzzleFixtures.approved.start]
    public private(set) var marks: Set<Cell> = []
    private var history: [([Cell], Set<Cell>)] = []
    public init() {}
    public var occupied: Set<Cell> { Set(path).union([goal]) }
    public var rowCounts: [Int] { (0..<5).map { r in occupied.filter { $0.row == r }.count } }
    public var columnCounts: [Int] { (0..<5).map { c in occupied.filter { $0.col == c }.count } }
    public var won: Bool { path.last == goal && rowCounts == rows && columnCounts == columns }
    public var canUndo: Bool { !history.isEmpty }
    @discardableResult public mutating func play(_ cell: Cell, marking: Bool = false) -> Bool {
        guard (0..<5).contains(cell.row), (0..<5).contains(cell.col), !won else { return false }
        let previous = (path, marks)
        if marking {
            guard !occupied.contains(cell) else { return false }
            if !marks.insert(cell).inserted { marks.remove(cell) }
        } else {
            if path.count > 1 && path[path.count - 2] == cell { path.removeLast() }
            else {
                guard let last = path.last, last != goal, !path.contains(cell), !marks.contains(cell), abs(last.row-cell.row)+abs(last.col-cell.col) == 1 else { return false }
                path.append(cell)
                if zip(rowCounts, rows).contains(where: { $0 > $1 }) || zip(columnCounts, columns).contains(where: { $0 > $1 }) { path = previous.0; return false }
            }
        }
        history.append(previous)
        return true
    }
    public mutating func undo() { if let state = history.popLast() { path = state.0; marks = state.1 } }
}

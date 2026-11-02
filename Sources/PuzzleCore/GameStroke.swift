/// A mistake the player can see: the offending cell plus the clue it broke, if any.
public struct StrokeViolation: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case rowExceeded, columnExceeded, arrivedEarly, obstacle, tree, nearCat, puddleTurn, givenEdge, crossedPath }
    public let kind: Kind
    public let cell: Cell
    public var row: Int?
    public var column: Int?
    public var explanation: String {
        switch kind {
        case .rowExceeded: return String(localized: "A linha \((row ?? 0)+1) passou do número.")
        case .columnExceeded: return String(localized: "A coluna \((column ?? 0)+1) passou do número.")
        case .arrivedEarly: return String(localized: "Ainda falta algo antes da casinha.")
        case .obstacle: return String(localized: "Arbusto no caminho!")
        case .tree: return String(localized: "A árvore fica ao lado do caminho, não nele.")
        case .nearCat: return String(localized: "Psiu! Perto do gato, não.")
        case .puddleTurn: return String(localized: "Na poça, só em linha reta.")
        case .givenEdge: return String(localized: "Esse trecho já estava desenhado.")
        case .crossedPath: return String(localized: "O caminho não pode se cruzar.")
        }
    }
}

/// A draft transaction: the live session is only replaced when the gesture ends.
public struct GameStroke: Sendable {
    private let original: Game
    private let marking: Bool
    private var visited: Set<Cell> = []
    private var lastInput: Cell?
    public private(set) var preview: Game
    public private(set) var violation: StrokeViolation?
    public var penaltyDetected: Bool { violation != nil }
    public init(game: Game, marking: Bool) {
        original = game; preview = game; self.marking = marking
        preview.discardStrokeHistory()
    }
    @discardableResult public mutating func move(to cell: Cell?) -> Bool {
        guard !penaltyDetected else { return false }
        guard let cell else { lastInput = nil; return false }
        guard cell != lastInput else { return false }
        lastInput = cell
        if marking && !visited.insert(cell).inserted { return false }
        // Game rejects diagonals/skips, obstacles, conflicts and exceeded clues.
        // We never interpolate a route the player did not actually draw.
        if !marking, let violation = visibleViolation(stepping: cell) {
            self.violation = violation; return false
        }
        let accepted = preview.play(cell, marking: marking)
        preview.discardStrokeHistory()
        return accepted
    }
    /// Orthogonal steps from the tip that break a rule shown on the board.
    private func visibleViolation(stepping cell: Cell) -> StrokeViolation? {
        let path = preview.path
        guard let tip = path.last, !preview.won, tip != preview.goal, preview.puzzle.contains(cell),
              abs(tip.row-cell.row)+abs(tip.col-cell.col) == 1 else { return nil }
        let puzzle = preview.puzzle
        if puzzle.trees.contains(cell) { return StrokeViolation(kind: .tree, cell: cell) }
        if puzzle.cats.contains(cell) || puzzle.catZone.contains(cell) { return StrokeViolation(kind: .nearCat, cell: cell) }
        if puzzle.blocked.contains(cell) { return StrokeViolation(kind: .obstacle, cell: cell) }
        if path.contains(cell) {
            // Stepping back onto the previous cell erases; anything else crosses the route.
            return path.count > 1 && path[path.count-2] == cell ? nil : StrokeViolation(kind: .crossedPath, cell: cell)
        }
        guard !preview.marks.contains(cell) else { return nil }
        switch RouteValidator.evaluate(puzzle: preview.puzzle, path: path + [cell]) {
        case .contradiction(.rowExceeded(let r)): return StrokeViolation(kind: .rowExceeded, cell: cell, row: r)
        case .contradiction(.columnExceeded(let c)): return StrokeViolation(kind: .columnExceeded, cell: cell, column: c)
        case .contradiction(.arrivedBeforeClues): return StrokeViolation(kind: .arrivedEarly, cell: cell)
        case .contradiction(.turnedOnPuddle): return StrokeViolation(kind: .puddleTurn, cell: tip)
        case .contradiction(.brokeGivenEdge): return StrokeViolation(kind: .givenEdge, cell: cell)
        default: return nil
        }
    }
    public func finish(cancelled: Bool = false) -> Game {
        var result = original
        if !cancelled { result.commitStroke(preview) }
        return result
    }
}

public enum BoardHitTest {
    /// Coordinates include the first row/column reserved for clues.
    public static func cell(x: Double, y: Double, side: Double, rows: Int, columns: Int) -> Cell? {
        guard x.isFinite, y.isFinite, side.isFinite, side > 0, rows > 0, columns > 0,
              x >= side, y >= side, x < Double(columns+1)*side, y < Double(rows+1)*side else { return nil }
        return Cell(Int(y/side)-1, Int(x/side)-1)
    }
}

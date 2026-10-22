/// A draft transaction: the live session is only replaced when the gesture ends.
public struct GameStroke: Sendable {
    private let original: Game
    private let marking: Bool
    private var visited: Set<Cell> = []
    private var lastInput: Cell?
    public private(set) var preview: Game
    public init(game: Game, marking: Bool) {
        original = game; preview = game; self.marking = marking
        preview.discardStrokeHistory()
    }
    @discardableResult public mutating func move(to cell: Cell?) -> Bool {
        guard let cell else { lastInput = nil; return false }
        guard cell != lastInput else { return false }
        lastInput = cell
        if marking && !visited.insert(cell).inserted { return false }
        // Game rejects diagonals/skips, obstacles, conflicts and exceeded clues.
        // We never interpolate a route the player did not actually draw.
        let accepted = preview.play(cell, marking: marking)
        preview.discardStrokeHistory()
        return accepted
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

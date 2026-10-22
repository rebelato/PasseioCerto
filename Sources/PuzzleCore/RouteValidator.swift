public enum RuleViolation: Equatable, Sendable {
    case wrongStart, outOfBounds, obstacle, repeatedCell, disconnected, continuedPastGoal, invalidMark
    case rowExceeded(Int), columnExceeded(Int), arrivedBeforeClues
}

public enum RouteStatus: Equatable, Sendable {
    /// No violation detected by these rules; this is not a proof of solvability.
    case incomplete
    case contradiction(RuleViolation)
    case complete
}

public enum RouteValidator {
    /// Structural errors also make persisted sessions invalid. Player deductions are not certified.
    public static func structuralViolation(puzzle: Puzzle, path: [Cell], marks: Set<Cell> = []) -> RuleViolation? {
        guard path.first == puzzle.start else { return .wrongStart }
        guard path.allSatisfy(puzzle.contains) else { return .outOfBounds }
        guard path.allSatisfy({ !puzzle.obstacles.contains($0) }) else { return .obstacle }
        guard Set(path).count == path.count else { return .repeatedCell }
        guard zip(path, path.dropFirst()).allSatisfy({ abs($0.row-$1.row)+abs($0.col-$1.col) == 1 }) else { return .disconnected }
        guard !path.dropLast().contains(puzzle.goal) else { return .continuedPastGoal }
        guard marks.allSatisfy({ puzzle.contains($0) && !puzzle.obstacles.contains($0) && $0 != puzzle.goal && !path.contains($0) }) else { return .invalidMark }
        return nil
    }
    public static func counts(puzzle: Puzzle, path: [Cell]) -> (rows: [Int], columns: [Int]) {
        let occupied = Set(path).union([puzzle.start, puzzle.goal])
        return (puzzle.rows.indices.map { r in occupied.filter { $0.row == r }.count },
                puzzle.columns.indices.map { c in occupied.filter { $0.col == c }.count })
    }
    public static func evaluate(puzzle: Puzzle, path: [Cell], marks: Set<Cell> = []) -> RouteStatus {
        if let error = structuralViolation(puzzle: puzzle, path: path, marks: marks) { return .contradiction(error) }
        let counts = counts(puzzle: puzzle, path: path)
        for r in puzzle.rows.indices where counts.rows[r] > puzzle.rows[r] { return .contradiction(.rowExceeded(r)) }
        for c in puzzle.columns.indices where counts.columns[c] > puzzle.columns[c] { return .contradiction(.columnExceeded(c)) }
        if path.last == puzzle.goal {
            return counts.rows == puzzle.rows && counts.columns == puzzle.columns ? .complete : .contradiction(.arrivedBeforeClues)
        }
        return .incomplete
    }
}

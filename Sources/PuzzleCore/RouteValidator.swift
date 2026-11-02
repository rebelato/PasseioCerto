public enum RuleViolation: Equatable, Sendable {
    case wrongStart, outOfBounds, obstacle, repeatedCell, disconnected, continuedPastGoal, invalidMark
    case rowExceeded(Int), columnExceeded(Int), arrivedBeforeClues
    case nearCat, turnedOnPuddle, brokeGivenEdge
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
        guard path.allSatisfy({ !puzzle.blocked.contains($0) }) else { return .obstacle }
        guard Set(path).count == path.count else { return .repeatedCell }
        guard zip(path, path.dropFirst()).allSatisfy({ $0.isAdjacent(to: $1) }) else { return .disconnected }
        if let goal = puzzle.knownGoal, path.dropLast().contains(goal) { return .continuedPastGoal }
        guard marks.allSatisfy({ puzzle.contains($0) && !puzzle.blocked.contains($0) && $0 != puzzle.knownGoal && !path.contains($0) }) else { return .invalidMark }
        return nil
    }
    /// Themed rules that a prefix can already break.
    public static func themedViolation(puzzle: Puzzle, path: [Cell]) -> RuleViolation? {
        guard puzzle.hasThemedRules else { return nil }
        if !puzzle.catZone.isEmpty, path.contains(where: puzzle.catZone.contains) { return .nearCat }
        for index in path.indices.dropFirst().dropLast() where puzzle.puddles.contains(path[index]) {
            let before = path[index-1], after = path[index+1]
            if before.row != after.row && before.col != after.col { return .turnedOnPuddle }
        }
        for edge in puzzle.givenEdges {
            for (cell, partner) in [(edge.a, edge.b), (edge.b, edge.a)] {
                guard let index = path.firstIndex(of: cell), index < path.count-1 || path.contains(partner) else { continue }
                let linked = (index > 0 && path[index-1] == partner) || (index+1 < path.count && path[index+1] == partner)
                if !linked { return .brokeGivenEdge }
            }
        }
        return nil
    }
    public static func counts(puzzle: Puzzle, path: [Cell]) -> (rows: [Int], columns: [Int]) {
        var rows = Array(repeating: 0, count: puzzle.rows.count), columns = Array(repeating: 0, count: puzzle.columns.count)
        // A hidden house is not counted in advance: that would point straight at it.
        for cell in Set(path).union([puzzle.start]).union(puzzle.knownGoal.map { [$0] } ?? []) { rows[cell.row] += 1; columns[cell.col] += 1 }
        return (rows, columns)
    }
    /// Bones visited and every tree passed beside.
    public static func stopsSatisfied(puzzle: Puzzle, path: [Cell]) -> Bool {
        let visited = Set(path)
        return puzzle.bones.isSubset(of: visited)
            && puzzle.trees.allSatisfy { tree in Cell.neighbors(tree).contains(where: visited.contains) }
            && puzzle.givenEdges.allSatisfy { visited.contains($0.a) && visited.contains($0.b) }
    }
    public static func evaluate(puzzle: Puzzle, path: [Cell], marks: Set<Cell> = []) -> RouteStatus {
        if let error = structuralViolation(puzzle: puzzle, path: path, marks: marks) { return .contradiction(error) }
        if let error = themedViolation(puzzle: puzzle, path: path) { return .contradiction(error) }
        let counts = counts(puzzle: puzzle, path: path)
        for r in puzzle.rows.indices where counts.rows[r] > puzzle.rows[r] { return .contradiction(.rowExceeded(r)) }
        for c in puzzle.columns.indices where counts.columns[c] > puzzle.columns[c] { return .contradiction(.columnExceeded(c)) }
        if puzzle.hiddenGoal {
            // Every clue met can only happen at the house: the generator certifies that.
            return counts.rows == puzzle.rows && counts.columns == puzzle.columns && stopsSatisfied(puzzle: puzzle, path: path)
                ? .complete : .incomplete
        }
        if path.last == puzzle.goal {
            return counts.rows == puzzle.rows && counts.columns == puzzle.columns && stopsSatisfied(puzzle: puzzle, path: path)
                ? .complete : .contradiction(.arrivedBeforeClues)
        }
        return .incomplete
    }
}

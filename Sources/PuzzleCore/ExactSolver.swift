/// Counts ordered routes, stopping after the second witness. No solution oracle is used.
public enum SolverClassification: Equatable, Sendable {
    case noSolution, unique, multiple, indeterminate
}
public struct SolverResult: Sendable {
    public let classification: SolverClassification
    public let solutions: [[Cell]]
    public let visitedNodes: Int
}
public enum ExactSolver {
    /// Exclusions constrain this query only; player marks are not proven deductions.
    /// Budget counts evaluated prefixes, including rejected prefixes. Cancellation is
    /// checked before each node. Caller should run substantial searches off the UI thread.
    ///
    /// Pruning is sound: a prefix is dropped only when no completion through cells still
    /// reachable from its tip could meet every clue and rule.
    public static func solve(puzzle: Puzzle, prefix: [Cell]? = nil, excluding: Set<Cell> = [],
                             nodeLimit: Int = 100_000, isCancelled: () -> Bool = { false }) -> SolverResult {
        var solutions: [[Cell]] = []
        var visited = 0
        var interrupted = false
        let unusable = puzzle.blocked.union(puzzle.catZone).union(excluding)
        func search(_ path: [Cell]) {
            guard solutions.count < 2, !interrupted else { return }
            guard !isCancelled(), visited < max(0, nodeLimit) else { interrupted = true; return }
            visited += 1
            switch RouteValidator.evaluate(puzzle: puzzle, path: path, marks: excluding) {
            case .contradiction: return
            case .complete: solutions.append(path); return
            case .incomplete: break
            }
            guard let last = path.last, canStillFinish(path) else { return }
            var options = Cell.neighbors(last)
            // A puddle is crossed straight; a pre-drawn piece must be followed.
            if path.count > 1, puzzle.puddles.contains(last) {
                let previous = path[path.count-2]
                options = [Cell(2*last.row-previous.row, 2*last.col-previous.col)]
            }
            for edge in puzzle.givenEdges {
                if let partner = edge.partner(of: last), !path.contains(partner) { options = options.filter { $0 == partner } }
            }
            // Fixed ordering makes budgets and witnesses reproducible across runs.
            for next in options {
                guard puzzle.contains(next), !unusable.contains(next), !path.contains(next) else { continue }
                search(path + [next])
                if interrupted || solutions.count == 2 { return }
            }
        }
        /// Optimistic bound: every cell reachable from the tip could still be used.
        func canStillFinish(_ path: [Cell]) -> Bool {
            let used = Set(path)
            var reachable: Set<Cell> = []
            var pending = [path.last!]
            while let cell = pending.popLast() {
                if cell == puzzle.knownGoal { continue }
                for next in Cell.neighbors(cell) where puzzle.contains(next) && !unusable.contains(next) && !used.contains(next) {
                    if reachable.insert(next).inserted { pending.append(next) }
                }
            }
            if let goal = puzzle.knownGoal, !reachable.contains(goal) { return false }
            let counts = RouteValidator.counts(puzzle: puzzle, path: path)
            var rows = counts.rows, columns = counts.columns
            for cell in reachable where cell != puzzle.knownGoal { rows[cell.row] += 1; columns[cell.col] += 1 }
            guard zip(rows, puzzle.rows).allSatisfy({ $0 >= $1 }), zip(columns, puzzle.columns).allSatisfy({ $0 >= $1 }) else { return false }
            let open = used.union(reachable)
            return puzzle.bones.isSubset(of: open)
                && puzzle.trees.allSatisfy { Cell.neighbors($0).contains(where: open.contains) }
                && puzzle.givenEdges.allSatisfy { open.contains($0.a) && open.contains($0.b) }
        }
        search(prefix ?? [puzzle.start])
        let classification: SolverClassification = solutions.count >= 2 ? .multiple : interrupted ? .indeterminate : solutions.isEmpty ? .noSolution : .unique
        return SolverResult(classification: classification, solutions: solutions, visitedNodes: visited)
    }
}

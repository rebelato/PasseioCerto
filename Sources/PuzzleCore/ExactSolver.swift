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
    public static func solve(puzzle: Puzzle, prefix: [Cell]? = nil, excluding: Set<Cell> = [],
                             nodeLimit: Int = 100_000, isCancelled: () -> Bool = { false }) -> SolverResult {
        var solutions: [[Cell]] = []
        var visited = 0
        var interrupted = false
        func search(_ path: [Cell]) {
            guard solutions.count < 2, !interrupted else { return }
            guard !isCancelled(), visited < max(0, nodeLimit) else { interrupted = true; return }
            visited += 1
            switch RouteValidator.evaluate(puzzle: puzzle, path: path, marks: excluding) {
            case .contradiction: return
            case .complete: solutions.append(path); return
            case .incomplete: break
            }
            guard let last = path.last else { return }
            // Fixed ordering makes budgets and witnesses reproducible across runs.
            for next in [Cell(last.row-1,last.col),Cell(last.row,last.col+1),Cell(last.row+1,last.col),Cell(last.row,last.col-1)] {
                guard puzzle.contains(next), !puzzle.obstacles.contains(next), !excluding.contains(next), !path.contains(next) else { continue }
                search(path + [next])
                if interrupted || solutions.count == 2 { return }
            }
        }
        search(prefix ?? [puzzle.start])
        let classification: SolverClassification = solutions.count >= 2 ? .multiple : interrupted ? .indeterminate : solutions.isEmpty ? .noSolution : .unique
        return SolverResult(classification: classification, solutions: solutions, visitedNodes: visited)
    }
}

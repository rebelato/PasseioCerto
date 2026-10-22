public struct GenerationReport: Sendable {
    public enum Outcome: Equatable, Sendable { case generated, fallback, cancelled }
    public let outcome: Outcome
    public let puzzle: Puzzle?
    public let candidates: Int
    public let rejectedBySolver: Int
    public let rejectedByLogic: Int
    public let rejectedByDifficulty: Int
}

public enum PuzzleGenerator {
    public static let version = 1
    /// Stable wrapping LCG; never uses process-randomized hash values.
    private struct Random {
        var state: UInt64
        mutating func next(_ bound: Int) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 32) % UInt64(bound))
        }
    }
    /// Bounded synchronous work; UI integration must run this off MainActor (PC-015).
    /// IDs include candidate index, so changing budgets never gives different grids one ID.
    public static func generate(seed: UInt64, difficulty: PuzzleDifficulty? = nil, candidateLimit: Int = 80, solverNodeLimit: Int = 20_000,
                                isCancelled: () -> Bool = { false }) -> GenerationReport {
        var rng = Random(state: seed)
        var attempted = 0
        var solverRejected = 0
        var logicRejected = 0
        var difficultyRejected = 0
        func result(_ outcome: GenerationReport.Outcome, _ puzzle: Puzzle? = nil) -> GenerationReport {
            GenerationReport(outcome: outcome, puzzle: puzzle, candidates: attempted, rejectedBySolver: solverRejected, rejectedByLogic: logicRejected, rejectedByDifficulty: difficultyRejected)
        }
        for index in 0..<min(1000, max(0, candidateLimit)) {
            if isCancelled() { return result(.cancelled) }
            attempted += 1
            var route = [Cell(rng.next(5), rng.next(5))]
            let length = 7 + rng.next(10)
            for _ in 1..<length {
                let tip = route.last!
                let choices = [Cell(tip.row-1,tip.col),Cell(tip.row,tip.col+1),Cell(tip.row+1,tip.col),Cell(tip.row,tip.col-1)].filter {
                    (0..<5).contains($0.row) && (0..<5).contains($0.col) && !route.contains($0)
                }
                if choices.isEmpty { break }
                route.append(choices[rng.next(choices.count)])
            }
            var obstacles: Set<Cell> = []
            for r in 0..<5 { for c in 0..<5 {
                let cell = Cell(r,c)
                if !route.contains(cell), rng.next(12) == 0 { obstacles.insert(cell) }
            } }
            let rows = (0..<5).map { r in route.filter { $0.row == r }.count }
            let columns = (0..<5).map { c in route.filter { $0.col == c }.count }
            guard let puzzle = try? Puzzle(puzzleID: "generated-v1-\(seed)-\(index)", generatorVersion: version, seed: seed, rows: rows, columns: columns, start: route[0], goal: route.last!, obstacles: obstacles) else { solverRejected += 1; continue }
            let exact = ExactSolver.solve(puzzle: puzzle, nodeLimit: min(1_000_000, max(0, solverNodeLimit)), isCancelled: isCancelled)
            if isCancelled() { return result(.cancelled) }
            guard exact.classification == .unique else { solverRejected += 1; continue }
            let logical = LogicEngine.analyze(puzzle: puzzle)
            if isCancelled() { return result(.cancelled) }
            guard logical.outcome == .solved, RouteValidator.evaluate(puzzle: puzzle, path: logical.path) == .complete else { logicRejected += 1; continue }
            if let difficulty, DifficultyClassifier.assess(puzzle)?.level != difficulty {
                difficultyRejected += 1; continue
            }
            return result(.generated, puzzle)
        }
        if isCancelled() { return result(.cancelled) }
        // Own stable ID; both validators certify this fixture in the test suite.
        return result(.fallback, difficulty.map { FallbackCatalog.puzzle(for: $0, seed: seed) } ?? (try! PuzzleFixtures.approved.makePuzzle()))
    }
}

public extension PuzzleGenerator {
    /// Explicit worker task keeps generation off MainActor and forwards cancellation.
    /// The screen still must discard superseded request IDs when integrating PC-015.
    static func generateAsync(seed: UInt64, difficulty: PuzzleDifficulty? = nil) async -> GenerationReport {
        let worker = Task.detached(priority: .userInitiated) {
            generate(seed: seed, difficulty: difficulty, isCancelled: { Task.isCancelled })
        }
        return await withTaskCancellationHandler {
            await worker.value
        } onCancel: {
            worker.cancel()
        }
    }
}

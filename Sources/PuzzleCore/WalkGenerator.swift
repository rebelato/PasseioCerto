import Foundation

/// How big the walk is. Only Fácil shows the house; every level has three lives.
public enum Difficulty: String, CaseIterable, Codable, Sendable {
    case easy, medium, hard, expert
    public var title: String {
        switch self {
        case .easy: String(localized: "Fácil")
        case .medium: String(localized: "Médio")
        case .hard: String(localized: "Difícil")
        case .expert: String(localized: "Especialista")
        }
    }
    public var size: Int {
        switch self {
        case .easy: 5
        case .medium: 7
        case .hard: 15
        case .expert: 20
        }
    }
    public var hiddenHouse: Bool { self != .easy }
}

/// Builds walks that logic alone can finish, which also proves the solution is unique:
/// every deduction holds in all solutions, so a fully forced route is the only one.
/// Instead of discarding grids where logic stalls, it reveals a route piece there and
/// tries again, so nearly every candidate becomes a puzzle.
public enum WalkGenerator {
    public static let version = 1
    private struct Random {
        var state: UInt64
        mutating func next(_ bound: Int) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 33) % UInt64(max(1, bound)))
        }
    }
    public static func generate(_ difficulty: Difficulty, variation: UInt64, id: String? = nil, candidateLimit: Int = 200,
                                isCancelled: () -> Bool = { false }) -> GenerationReport {
        var rng = Random(state: variation &* 0x9E3779B97F4A7C15 &+ UInt64(difficulty.size))
        var attempted = 0, logicRejected = 0
        let n = difficulty.size
        for index in 0..<max(0, candidateLimit) {
            if isCancelled() { return report(.cancelled, nil, attempted, logicRejected) }
            attempted += 1
            // Of a few candidate routes, keep the one whose rows and columns are least broken up.
            let options = (0..<(n >= 15 ? 16 : 8)).compactMap { _ in looseRoute(n, rng: &rng) }
            // Routes that mostly run along the border would win that contest but play like a frame.
            let border = { (route: [Cell]) in route.filter { $0.row == 0 || $0.col == 0 || $0.row == n-1 || $0.col == n-1 }.count }
            let inland = options.filter { border($0) * 100 <= $0.count * 30 }
            guard let route = (inland.isEmpty ? options : inland).min(by: { pieces($0) < pieces($1) }) ?? Optional(coveringRoute(n, rng: &rng)) else { continue }
            let rows = (0..<n).map { r in route.filter { $0.row == r }.count }
            let columns = (0..<n).map { c in route.filter { $0.col == c }.count }
            let puzzleID = id ?? "walk-v\(version)-\(difficulty.rawValue)-\(variation)-\(index)"
            var given: [GivenEdge] = []
            // Reveal route pieces where logic stalls, up to a budget that keeps grids interesting.
            // Difícil and Especialista get none: their compact routes are solved by logic alone.
            let budget = n >= 15 ? 0 : max(1, n*n/9)
            let perRound = max(1, n/6)
            while given.count <= budget {
                if isCancelled() { return report(.cancelled, nil, attempted, logicRejected) }
                guard let puzzle = try? Puzzle(puzzleID: puzzleID, schemaVersion: 2, generatorVersion: version, seed: variation, rows: rows, columns: columns,
                                               start: route[0], goal: route.last!, givenEdges: given, hiddenGoal: difficulty.hiddenHouse) else { break }
                let analysis = LogicEngine.analyze(puzzle: puzzle, maxTier: LogicEngine.fullTier)
                if analysis.outcome == .solved {
                    return report(.generated, minimized(puzzle, rng: &rng, isCancelled: isCancelled), attempted, logicRejected)
                }
                guard analysis.outcome == .stalled else { break }
                // A piece where nothing is known yet anchors the most new deductions.
                let open = route.indices.dropLast().filter {
                    !analysis.required.contains(route[$0]) && !analysis.required.contains(route[$0+1])
                }
                // Everything known but the order: reveal a piece beyond the drawn part, so forced
                // links can spread from it.
                let beyond = Array(max(0, analysis.path.count - 1)..<(route.count - 1))
                guard route.starts(with: analysis.path), !(open.isEmpty && beyond.isEmpty) else { break }
                // Big grids reveal a few pieces per round: each analysis of a 20×20 is the costly part.
                for _ in 0..<perRound {
                    let pool = open.isEmpty ? beyond : open
                    let i = pool[rng.next(pool.count)]
                    let piece = GivenEdge(route[i], route[i+1])
                    if !given.contains(piece) { given.append(piece) }
                }
            }
            logicRejected += 1
        }
        if isCancelled() { return report(.cancelled, nil, attempted, logicRejected) }
        return report(.fallback, FallbackCatalog.walk(for: difficulty, variation: variation, id: id), attempted, logicRejected)
    }
    /// Drops revealed pieces that logic can do without, so only the needed hints stay.
    private static func minimized(_ puzzle: Puzzle, rng: inout Random, isCancelled: () -> Bool) -> Puzzle {
        var kept = puzzle.givenEdges
        var order = Array(kept.indices)
        for i in order.indices.reversed() { order.swapAt(i, rng.next(i+1)) }
        var best = puzzle
        for index in order.sorted(by: >) where !isCancelled() {
            var trial = kept
            trial.remove(at: index)
            guard let candidate = try? Puzzle(puzzleID: puzzle.puzzleID, schemaVersion: 2, generatorVersion: puzzle.generatorVersion, seed: puzzle.seed,
                                              rows: puzzle.rows, columns: puzzle.columns, start: puzzle.start, goal: puzzle.goal,
                                              givenEdges: trial, hiddenGoal: puzzle.hiddenGoal),
                  LogicEngine.analyze(puzzle: candidate, maxTier: LogicEngine.fullTier).outcome == .solved else { continue }
            kept = trial; best = candidate
        }
        return best
    }
    private static func report(_ outcome: GenerationReport.Outcome, _ puzzle: Puzzle?, _ attempted: Int, _ logic: Int) -> GenerationReport {
        GenerationReport(outcome: outcome, puzzle: puzzle, candidates: attempted, rejectedBySolver: 0, rejectedByLogic: logic, rejectedByDifficulty: 0)
    }

    /// How many separate runs the route makes across all rows and columns (2n means every line is in one piece).
    static func pieces(_ route: [Cell]) -> Int {
        func runs(_ values: [Int]) -> Int {
            let sorted = values.sorted()
            return sorted.isEmpty ? 0 : 1 + zip(sorted, sorted.dropFirst()).filter { $1 - $0 > 1 }.count
        }
        return Dictionary(grouping: route, by: \.row).values.map { runs($0.map(\.col)) }.reduce(0, +)
            + Dictionary(grouping: route, by: \.col).values.map { runs($0.map(\.row)) }.reduce(0, +)
    }
    /// A route that never brushes against itself: each cell touches only the cells before and
    /// after it, and that keeps the cells of each row and column together where it can. Once logic knows which cells are on the route, their order follows, which is
    /// what lets 15×15 and 20×20 be solved without guessing. Also touches every row and column.
    private static func looseRoute(_ n: Int, rng: inout Random) -> [Cell]? {
        let inside = { (c: Cell) in (0..<n).contains(c.row) && (0..<n).contains(c.col) }
        // Big grids get relatively short, compact routes: each line's cells stay together, and logic
        // finishes them without any pre-drawn piece (20×20 about 40–56 cells, 15×15 about 31–40).
        let target = n >= 20 ? n*n*10/100 + rng.next(max(1, n*n*4/100))
            : n >= 15 ? n*n*14/100 + rng.next(max(1, n*n*4/100))
            : n*n*30/100 + rng.next(max(1, n*n*12/100))
        for _ in 0..<60 {
            var route = [Cell(rng.next(n), rng.next(n))]
            var taken: Set<Cell> = [route[0]]
            var rowCount = Array(repeating: 0, count: n), columnCount = Array(repeating: 0, count: n)
            rowCount[route[0].row] = 1; columnCount[route[0].col] = 1
            while route.count < target {
                let tip = route.last!
                let options = Cell.neighbors(tip).filter { next in
                    inside(next) && !taken.contains(next) && Cell.neighbors(next).allSatisfy { $0 == tip || !taken.contains($0) }
                }
                if options.isEmpty { break }
                // Prefer cells that keep each row and column in one piece (a cell starts a new piece
                // when its line already has route cells and none beside it); sometimes take the most
                // constrained way to avoid traps, sometimes wander for variety.
                let exits = { (c: Cell) in Cell.neighbors(c).filter { inside($0) && !taken.contains($0) }.count }
                let pieces = { (c: Cell) -> Int in
                    let row = rowCount[c.row] > 0 && !taken.contains(Cell(c.row, c.col-1)) && !taken.contains(Cell(c.row, c.col+1))
                    let column = columnCount[c.col] > 0 && !taken.contains(Cell(c.row-1, c.col)) && !taken.contains(Cell(c.row+1, c.col))
                    return (row ? 1 : 0) + (column ? 1 : 0)
                }
                let fewest = options.map(pieces).min()!
                let together = options.filter { pieces($0) == fewest }
                let roll = rng.next(6)
                let pick = roll < 4 ? together[rng.next(together.count)]
                    : roll == 4 ? options.min(by: { exits($0) < exits($1) })! : options[rng.next(options.count)]
                rowCount[pick.row] += 1; columnCount[pick.col] += 1
                route.append(pick); taken.insert(pick)
            }
            if route.count >= target * 3 / 4, Set(route.map(\.row)).count == n, Set(route.map(\.col)).count == n { return route }
        }
        return nil
    }
    /// A random route that touches every row and column, so no clue is 0.
    /// It is a slice of a random Hamiltonian path (backbite moves on a zigzag),
    /// which wanders the whole grid without trapping itself or hugging the walls.
    private static func coveringRoute(_ n: Int, rng: inout Random) -> [Cell] {
        var path = (0..<n).flatMap { r in (0..<n).map { Cell(r, r % 2 == 0 ? $0 : n-1-$0) } }
        var index = [Cell: Int]()
        func reindex() { for (i, c) in path.enumerated() { index[c] = i } }
        reindex()
        let inside = { (c: Cell) in (0..<n).contains(c.row) && (0..<n).contains(c.col) }
        for _ in 0..<(n*n*8) {
            // Backbite: join an end to a neighbour and reverse the loop that forms.
            let fromStart = rng.next(2) == 0
            if fromStart { path.reverse(); reindex() }
            let end = path.last!
            let options = Cell.neighbors(end).filter { inside($0) && $0 != path[path.count-2] }
            guard !options.isEmpty else { continue }
            let j = index[options[rng.next(options.count)]]!
            path[(j+1)...].reverse()
            for k in (j+1)..<path.count { index[path[k]] = k }
        }
        for _ in 0..<200 {
            let length = n*n*35/100 + rng.next(max(1, n*n*25/100))
            let start = rng.next(n*n - length + 1)
            let slice = Array(path[start..<(start+length)])
            if Set(slice.map(\.row)).count == n && Set(slice.map(\.col)).count == n { return slice }
        }
        return path
    }
}

public extension WalkGenerator {
    /// Explicit worker task keeps generation off MainActor and forwards cancellation.
    static func generateAsync(_ difficulty: Difficulty, variation: UInt64, id: String? = nil) async -> GenerationReport {
        let worker = Task.detached(priority: .userInitiated) {
            generate(difficulty, variation: variation, id: id, isCancelled: { Task.isCancelled })
        }
        return await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
    }
}

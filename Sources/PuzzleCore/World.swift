import Foundation

public enum ThemedRule: String, CaseIterable, Codable, Sendable {
    case bone, tree, cat, puddle
    public var title: String {
        switch self {
        case .bone: String(localized: "Osso")
        case .tree: String(localized: "Árvore")
        case .cat: String(localized: "Gato")
        case .puddle: String(localized: "Poça")
        }
    }
    public var explanation: String {
        switch self {
        case .bone: String(localized: "O caminho precisa passar pelo osso.")
        case .tree: String(localized: "Parada obrigatória: o caminho passa ao lado de cada árvore.")
        case .cat: String(localized: "O caminho não pode passar ao lado do gato.")
        case .puddle: String(localized: "Na poça, só em linha reta.")
        }
    }
}

/// Places to walk, in order. Each one grows the grid and introduces one rule.
public enum World: Int, CaseIterable, Codable, Comparable, Sendable {
    case flowerSquare, beach, market, park, pond
    public static func < (a: World, b: World) -> Bool { a.rawValue < b.rawValue }
    public static let levelsPerWorld = 8
    public var title: String {
        switch self {
        case .flowerSquare: String(localized: "Praça das Flores")
        case .beach: String(localized: "Praia")
        case .market: String(localized: "Feira")
        case .park: String(localized: "Parque")
        case .pond: String(localized: "Lagoa")
        }
    }
    public var symbol: String {
        switch self {
        case .flowerSquare: "camera.macro"
        case .beach: "beach.umbrella"
        case .market: "basket"
        case .park: "tree"
        case .pond: "drop"
        }
    }
    public var size: Int {
        switch self {
        case .flowerSquare: 5
        case .beach: 6
        case .market: 8
        case .park, .pond: 10
        }
    }
    /// The rule this world introduces.
    public var newRule: ThemedRule? {
        switch self {
        case .flowerSquare: nil
        case .beach: .bone
        case .market: .tree
        case .park: .cat
        case .pond: .puddle
        }
    }
    /// Rules met so far; earlier ones keep appearing now and then.
    public var rules: [ThemedRule] { World.allCases.filter { $0 <= self }.compactMap(\.newRule) }
    public var next: World? { World(rawValue: rawValue + 1) }
}

public struct WorldLevel: Codable, Hashable, Sendable {
    public let world: World
    public let level: Int
    /// Laps around the last world after finishing everything; each lap brings new grids.
    public let round: Int
    public init(world: World, level: Int, round: Int = 0) {
        self.world = world; self.level = min(max(level, 0), World.levelsPerWorld-1); self.round = max(0, round)
    }
    public static let first = WorldLevel(world: .flowerSquare, level: 0)
    public var title: String { String(localized: "\(world.title) · \(level+1)/\(World.levelsPerWorld)") }
    /// The level after this one; after the last world, another lap of it with fresh grids.
    public var next: WorldLevel {
        if level + 1 < World.levelsPerWorld { return WorldLevel(world: world, level: level+1, round: round) }
        if let following = world.next { return WorldLevel(world: following, level: 0, round: round) }
        return WorldLevel(world: world, level: 0, round: round+1)
    }
    public var seed: UInt64 { UInt64(world.rawValue) &* 1_000_003 &+ UInt64(level) &* 7_919 &+ UInt64(round) &* 104_729 &+ 20_261_023 }
    /// Technique tiers a level may require. Extending the route always needs tier 2, so early
    /// levels use only counting and continuation, and the last ones need reachability or more.
    public var tiers: ClosedRange<Int> {
        switch level {
        case 0..<3: 2...2
        case 3..<6: 2...3
        default: 3...LogicEngine.maxTier
        }
    }
}

public enum WorldGenerator {
    public static let version = 1
    private struct Random {
        var state: UInt64
        mutating func next(_ bound: Int) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 33) % UInt64(max(1, bound)))
        }
        mutating func pick<T>(_ items: [T], count: Int) -> [T] {
            var pool = items, chosen: [T] = []
            while chosen.count < count, !pool.isEmpty { chosen.append(pool.remove(at: next(pool.count))) }
            return chosen
        }
    }
    /// Deterministic for a level and attempt: same inputs always give the same grid.
    /// `attempt` lets "Jogar de novo" on an exhausted world still vary; level progression uses 0.
    /// `hiddenHouse` certifies the grid without knowing where the walk ends.
    public static func generate(_ level: WorldLevel, attempt: UInt64 = 0, hiddenHouse: Bool = false, candidateLimit: Int = 3_000, solverNodeLimit: Int = 60_000,
                                isCancelled: () -> Bool = { false }) -> GenerationReport {
        var rng = Random(state: level.seed &+ attempt &* 0x9E3779B97F4A7C15 &+ (hiddenHouse ? 0xC0FFEE : 0))
        var attempted = 0, solverRejected = 0, logicRejected = 0, difficultyRejected = 0
        func result(_ outcome: GenerationReport.Outcome, _ puzzle: Puzzle? = nil) -> GenerationReport {
            GenerationReport(outcome: outcome, puzzle: puzzle, candidates: attempted, rejectedBySolver: solverRejected, rejectedByLogic: logicRejected, rejectedByDifficulty: difficultyRejected)
        }
        // Closest verified grid to the requested difficulty, kept in case none lands inside it.
        var best: (puzzle: Puzzle, distance: Int, deductions: Int)?
        for index in 0..<min(5_000, max(0, candidateLimit)) {
            if isCancelled() { return result(.cancelled) }
            attempted += 1
            guard let puzzle = candidate(level, id: "world-v\(version)\(hiddenHouse ? "h" : "")-\(level.world.rawValue)-\(level.level)-r\(level.round)-\(attempt)-\(index)", hidden: hiddenHouse, rng: &rng) else { solverRejected += 1; continue }
            let logical = LogicEngine.analyze(puzzle: puzzle)
            guard logical.outcome == .solved, let tier = LogicEngine.requiredTier(puzzle) else { logicRejected += 1; continue }
            if isCancelled() { return result(.cancelled) }
            // Logic solving proves a solution exists; the exact search proves it is the only one.
            let exact = ExactSolver.solve(puzzle: puzzle, nodeLimit: solverNodeLimit, isCancelled: isCancelled)
            if isCancelled() { return result(.cancelled) }
            guard exact.classification == .unique else { solverRejected += 1; continue }
            if level.tiers.contains(tier) { return result(.generated, puzzle) }
            difficultyRejected += 1
            let distance = tier < level.tiers.lowerBound ? level.tiers.lowerBound - tier : tier - level.tiers.upperBound
            // Among near misses, hard levels prefer longer deduction chains and easy ones shorter.
            let chain = level.tiers.lowerBound >= 3 ? logical.deductions.count : -logical.deductions.count
            if best.map({ distance < $0.distance || (distance == $0.distance && chain > $0.deductions) }) ?? true {
                best = (puzzle, distance, chain)
            }
        }
        if isCancelled() { return result(.cancelled) }
        if let best { return result(.generated, best.puzzle) }
        return result(.fallback, FallbackCatalog.puzzle(for: level, hiddenHouse: hiddenHouse))
    }

    private static func candidate(_ level: WorldLevel, id: String, hidden: Bool, rng: inout Random) -> Puzzle? {
        let n = level.world.size
        let inside = { (c: Cell) in (0..<n).contains(c.row) && (0..<n).contains(c.col) }
        // Self-avoiding random walk.
        var route = [Cell(rng.next(n), rng.next(n))]
        let target = n*n*30/100 + rng.next(max(1, n*n*25/100))
        while route.count < target {
            let tip = route.last!
            let options = Cell.neighbors(tip).filter { inside($0) && !route.contains($0) }
            if options.isEmpty { break }
            let exits = { (c: Cell) in Cell.neighbors(c).filter { inside($0) && !route.contains($0) && $0 != c }.count }
            // Small grids wander freely; 10×10 leans on avoiding traps so logic can still finish them.
            // Always taking the fewest exits would hug the walls.
            let fewest = options.map(exits).min()!
            let pool = (n >= 10 ? rng.next(3) != 0 : rng.next(3) == 0) ? options.filter { exits($0) == fewest } : options.filter { exits($0) > 0 || options.count == 1 }
            let choices = pool.isEmpty ? options : pool
            route.append(choices[rng.next(choices.count)])
        }
        guard route.count >= max(6, n*n/4) else { return nil }
        let onRoute = Set(route)
        let all = (0..<n).flatMap { r in (0..<n).map { Cell(r, $0) } }
        let interior = Array(route.dropFirst().dropLast())
        var bones: Set<Cell> = [], trees: Set<Cell> = [], cats: Set<Cell> = [], puddles: Set<Cell> = []
        for rule in level.world.rules where rule == level.world.newRule || rng.next(2) == 0 {
            let count = 1 + rng.next(rule == level.world.newRule ? 2 : 1)
            switch rule {
            case .bone:
                bones.formUnion(rng.pick(interior.filter { !puddles.contains($0) }, count: count))
            case .puddle:
                let straight = route.indices.dropFirst().dropLast().filter { i in
                    route[i-1].row == route[i+1].row || route[i-1].col == route[i+1].col
                }.map { route[$0] }.filter { !bones.contains($0) }
                puddles.formUnion(rng.pick(straight, count: count))
            case .tree:
                let beside = all.filter { !onRoute.contains($0) && !cats.contains($0) && Cell.neighbors($0).contains(where: onRoute.contains) }
                trees.formUnion(rng.pick(beside, count: count))
            case .cat:
                let lonely = all.filter { c in !onRoute.contains(c) && !trees.contains(c) && Cell.neighbors(c).allSatisfy { !onRoute.contains($0) } }
                cats.formUnion(rng.pick(lonely, count: count))
            }
        }
        var shrubs: Set<Cell> = []
        for cell in all where !onRoute.contains(cell) && !trees.contains(cell) && !cats.contains(cell) && rng.next(10) == 0 { shrubs.insert(cell) }
        var given: [GivenEdge] = []
        // Pre-drawn pieces anchor deductions on the big grids.
        if n >= 8 {
            for i in rng.pick(Array(0..<(route.count-1)), count: (n >= 10 ? n/2 : n/3) + rng.next(3)) { given.append(GivenEdge(route[i], route[i+1])) }
        }
        let rows = (0..<n).map { r in route.filter { $0.row == r }.count }
        let columns = (0..<n).map { c in route.filter { $0.col == c }.count }
        let themed = !(bones.isEmpty && trees.isEmpty && cats.isEmpty && puddles.isEmpty && given.isEmpty)
        return try? Puzzle(puzzleID: id, schemaVersion: themed || hidden ? 2 : 1, generatorVersion: version, seed: level.seed, rows: rows, columns: columns,
                           start: route[0], goal: route.last!, obstacles: shrubs, bones: bones, trees: trees, cats: cats, puddles: puddles, givenEdges: given, hiddenGoal: hidden)
    }
}

public extension WorldGenerator {
    /// Explicit worker task keeps generation off MainActor and forwards cancellation.
    static func generateAsync(_ level: WorldLevel, attempt: UInt64 = 0, hiddenHouse: Bool = false) async -> GenerationReport {
        let worker = Task.detached(priority: .userInitiated) {
            generate(level, attempt: attempt, hiddenHouse: hiddenHouse, isCancelled: { Task.isCancelled })
        }
        return await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
    }
}

import Foundation
public struct Deduction: Equatable, Sendable {
    public enum Action: Equatable, Sendable { case required(Cell), excluded(Cell), extend(Cell) }
    public enum Reason: Equatable, Sendable {
        case rowComplete(Int), columnComplete(Int), rowRemaining(Int), columnRemaining(Int)
        case unreachable, onlyContinuation
        case catNearby, givenSegment, puddleStraight, puddleBlocked, treeNeedsVisit
        /// Techniques in increasing order of subtlety; difficulty is the highest one a puzzle needs.
        public var tier: Int {
            switch self {
            case .rowComplete, .columnComplete, .rowRemaining, .columnRemaining, .catNearby: 1
            case .onlyContinuation, .givenSegment, .puddleStraight: 2
            case .unreachable: 3
            case .puddleBlocked, .treeNeedsVisit: 4
            }
        }
    }
    public let action: Action
    public let reason: Reason
    public var explanation: String {
        switch reason {
        case .rowComplete(let r): return String(localized: "A linha \(r+1) já está completa, então esta casa fica fora do caminho.")
        case .columnComplete(let c): return String(localized: "A coluna \(c+1) já está completa, então esta casa fica fora do caminho.")
        case .rowRemaining(let r): return String(localized: "A linha \(r+1) só tem as casas que faltam para a pista: todas entram no caminho.")
        case .columnRemaining(let c): return String(localized: "A coluna \(c+1) só tem as casas que faltam para a pista: todas entram no caminho.")
        case .unreachable: return String(localized: "Daqui não dá para chegar a esta casa sem cruzar o caminho ou casas excluídas.")
        case .onlyContinuation: return String(localized: "A ponta do caminho só tem uma saída livre.")
        case .catNearby: return String(localized: "Esta casa fica ao lado do gato, então o caminho não passa por ela.")
        case .givenSegment: return String(localized: "Este trecho já vem desenhado: o caminho segue por ele.")
        case .puddleStraight: return String(localized: "Na poça o caminho segue reto.")
        case .puddleBlocked: return String(localized: "Não dá para atravessar esta poça em linha reta, então o caminho não passa por ela.")
        case .treeNeedsVisit: return String(localized: "O caminho precisa passar ao lado da árvore, e esta é a única casa livre ao lado dela.")
        }
    }
}
public struct LogicResult: Sendable {
    public enum Outcome: Equatable, Sendable { case solved, stalled, contradiction(String) }
    public let outcome: Outcome
    public let deductions: [Deduction]
    public let path: [Cell]
    /// All conclusions are conditional on these player hypotheses and the supplied prefix.
    public let assumedMarks: Set<Cell>
    /// Highest technique tier used; 0 when nothing needed deducing.
    public var hardestTier: Int { deductions.map(\.reason.tier).max() ?? 0 }
}
public enum LogicEngine {
    public static let maxTier = 4
    /// Monotonic propagation only. No solver, reference route or trial hypotheses.
    /// `maxTier` limits which techniques may be used, to measure what a puzzle requires.
    public static func analyze(puzzle: Puzzle, prefix: [Cell]? = nil, marks: Set<Cell> = [], maxTier: Int = LogicEngine.maxTier) -> LogicResult {
        var path = prefix ?? [puzzle.start]
        var required = Set(path).union([puzzle.start, puzzle.goal]).union(puzzle.bones)
        for edge in puzzle.givenEdges { required.formUnion([edge.a, edge.b]) }
        var excluded = marks.union(puzzle.blocked)
        var deductions: [Deduction] = []
        let all = puzzle.rows.indices.flatMap { r in puzzle.columns.indices.map { Cell(r,$0) } }
        func result(_ outcome: LogicResult.Outcome) -> LogicResult {
            LogicResult(outcome: outcome, deductions: deductions, path: path, assumedMarks: marks)
        }
        func exclude(_ cell: Cell, _ reason: Deduction.Reason) {
            if excluded.insert(cell).inserted { deductions.append(Deduction(action: .excluded(cell), reason: reason)) }
        }
        func require(_ cell: Cell, _ reason: Deduction.Reason) {
            if required.insert(cell).inserted { deductions.append(Deduction(action: .required(cell), reason: reason)) }
        }
        for cell in puzzle.catZone.sorted(by: { ($0.row, $0.col) < ($1.row, $1.col) }) where !path.contains(cell) { exclude(cell, .catNearby) }
        while true {
            switch RouteValidator.evaluate(puzzle: puzzle, path: path, marks: marks) {
            case .complete: return result(.solved)
            case .contradiction: return result(.contradiction(String(localized: "O caminho ou as marcações quebram uma regra. Revise o estado atual ou use Desfazer.")))
            case .incomplete: break
            }
            if !required.isDisjoint(with: excluded) {
                return result(.contradiction(String(localized: "Uma casa obrigatória está marcada com ×. Revise as marcações.")))
            }
            let before = deductions.count
            // Tier 1: clue counting.
            for axis in 0..<2 {
                let clues = axis == 0 ? puzzle.rows : puzzle.columns
                for index in clues.indices {
                    let cells = all.filter { axis == 0 ? $0.row == index : $0.col == index }
                    let known = cells.filter { required.contains($0) }.count
                    let available = cells.filter { !excluded.contains($0) }
                    guard known <= clues[index], available.count >= clues[index] else {
                        let line = axis == 0 ? String(localized: "A linha \(index+1)") : String(localized: "A coluna \(index+1)")
                        return result(.contradiction(line + String(localized: " não consegue atender à pista com o caminho e as marcações atuais.")))
                    }
                    if known == clues[index] {
                        for cell in available where !required.contains(cell) { exclude(cell, axis == 0 ? .rowComplete(index) : .columnComplete(index)) }
                    } else if available.count == clues[index] {
                        for cell in available { require(cell, axis == 0 ? .rowRemaining(index) : .columnRemaining(index)) }
                    }
                }
            }
            // Order matches the v1 engine (counting, reachability, continuation): the daily
            // challenge policy depends on the trace this produces for puzzles without themes.
            let tip = path.last!
            // Tier 3: reachability. Flood fill overestimates reachable cells; the goal cannot be crossed.
            if maxTier >= 3 {
                let used = Set(path.dropLast())
                var reachable: Set<Cell> = [tip]
                var pending = [tip]
                while let cell = pending.popLast() {
                    if cell == puzzle.goal { continue }
                    for next in puzzle.neighbors(cell) where !excluded.contains(next) && !used.contains(next) {
                        if reachable.insert(next).inserted { pending.append(next) }
                    }
                }
                guard required.subtracting(Set(path)).isSubset(of: reachable) else {
                    return result(.contradiction(String(localized: "Uma casa obrigatória ou a casinha ficou sem ligação possível com a ponta do caminho. Revise as marcações ou desfaça um trecho.")))
                }
                for cell in all where !required.contains(cell) && !excluded.contains(cell) && !reachable.contains(cell) { exclude(cell, .unreachable) }
            }
            // Tier 2: how the tip must continue.
            if maxTier >= 2 {
                var next = Cell.neighbors(tip).filter { puzzle.contains($0) && !excluded.contains($0) && !path.contains($0) }
                var reason = Deduction.Reason.onlyContinuation
                if path.count > 1, puzzle.puddles.contains(tip) {
                    let previous = path[path.count-2]
                    next = next.filter { $0 == Cell(2*tip.row-previous.row, 2*tip.col-previous.col) }; reason = .puddleStraight
                }
                if let partner = puzzle.givenEdges.lazy.compactMap({ $0.partner(of: tip) }).first(where: { !path.contains($0) }) {
                    next = next.filter { $0 == partner }; reason = .givenSegment
                }
                if next.isEmpty { return result(.contradiction(String(localized: "A ponta do caminho ficou sem saída antes da casinha."))) }
                if next.count == 1 {
                    path.append(next[0]); required.insert(next[0])
                    deductions.append(Deduction(action: .extend(next[0]), reason: reason))
                }
            }
            // Tier 4: themed rules that need a closer look.
            if maxTier >= 4 {
                for puddle in puzzle.puddles where !required.contains(puddle) && !excluded.contains(puddle) {
                    let open = { (c: Cell) in puzzle.contains(c) && !excluded.contains(c) }
                    let across = open(Cell(puddle.row, puddle.col-1)) && open(Cell(puddle.row, puddle.col+1))
                    let down = open(Cell(puddle.row-1, puddle.col)) && open(Cell(puddle.row+1, puddle.col))
                    if !across && !down { exclude(puddle, .puddleBlocked) }
                }
                for tree in puzzle.trees where !puzzle.neighbors(tree).contains(where: required.contains) {
                    let spots = puzzle.neighbors(tree).filter { !excluded.contains($0) }
                    if spots.count == 1 { require(spots[0], .treeNeedsVisit) }
                    else if spots.isEmpty { return result(.contradiction(String(localized: "Não sobrou casa livre ao lado de uma árvore."))) }
                }
            }
            if deductions.count == before { return result(.stalled) }
        }
    }
    /// The simplest technique tier that solves the puzzle, or nil if logic alone cannot.
    public static func requiredTier(_ puzzle: Puzzle) -> Int? {
        (1...maxTier).first { analyze(puzzle: puzzle, maxTier: $0).outcome == .solved }
    }
}

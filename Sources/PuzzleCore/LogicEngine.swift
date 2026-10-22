public struct Deduction: Equatable, Sendable {
    public enum Action: Equatable, Sendable { case required(Cell), excluded(Cell), extend(Cell) }
    public enum Reason: Equatable, Sendable {
        case rowComplete(Int), columnComplete(Int), rowRemaining(Int), columnRemaining(Int)
        case unreachable, onlyContinuation
    }
    public let action: Action
    public let reason: Reason
    public var explanation: String {
        switch reason {
        case .rowComplete(let r): return "A linha \(r+1) já tem todas as casas necessárias. As demais ficam fora do caminho."
        case .columnComplete(let c): return "A coluna \(c+1) já tem todas as casas necessárias. As demais ficam fora do caminho."
        case .rowRemaining(let r): return "Na linha \(r+1), todas as casas restantes são necessárias para completar a pista."
        case .columnRemaining(let c): return "Na coluna \(c+1), todas as casas restantes são necessárias para completar a pista."
        case .unreachable: return "Esta casa não pode ser alcançada a partir da ponta sem atravessar casas excluídas ou repetir o caminho."
        case .onlyContinuation: return "A ponta do caminho tem apenas uma casa vizinha disponível para continuar."
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
}
public enum LogicEngine {
    /// Monotonic propagation only. No solver, reference route or trial hypotheses.
    public static func analyze(puzzle: Puzzle, prefix: [Cell]? = nil, marks: Set<Cell> = []) -> LogicResult {
        var path = prefix ?? [puzzle.start]
        var required = Set(path).union([puzzle.start, puzzle.goal])
        var excluded = marks.union(puzzle.obstacles)
        var deductions: [Deduction] = []
        let all = puzzle.rows.indices.flatMap { r in puzzle.columns.indices.map { Cell(r,$0) } }
        func result(_ outcome: LogicResult.Outcome) -> LogicResult {
            LogicResult(outcome: outcome, deductions: deductions, path: path, assumedMarks: marks)
        }
        func neighbors(_ c: Cell) -> [Cell] {
            [Cell(c.row-1,c.col),Cell(c.row,c.col+1),Cell(c.row+1,c.col),Cell(c.row,c.col-1)].filter(puzzle.contains)
        }
        while true {
            switch RouteValidator.evaluate(puzzle: puzzle, path: path, marks: marks) {
            case .complete: return result(.solved)
            case .contradiction: return result(.contradiction("O caminho ou as marcações violam uma regra. Revise o estado atual ou use Desfazer."))
            case .incomplete: break
            }
            let before = deductions.count
            for axis in 0..<2 {
                let clues = axis == 0 ? puzzle.rows : puzzle.columns
                for index in clues.indices {
                    let cells = all.filter { axis == 0 ? $0.row == index : $0.col == index }
                    let known = cells.filter { required.contains($0) }.count
                    let available = cells.filter { !excluded.contains($0) }
                    guard known <= clues[index], available.count >= clues[index] else {
                        return result(.contradiction("A \(axis == 0 ? "linha" : "coluna") \(index+1) não consegue atender à pista com o caminho e as marcações atuais."))
                    }
                    if known == clues[index] {
                        for cell in available where !required.contains(cell) {
                            excluded.insert(cell)
                            deductions.append(Deduction(action: .excluded(cell), reason: axis == 0 ? .rowComplete(index) : .columnComplete(index)))
                        }
                    } else if available.count == clues[index] {
                        for cell in available where required.insert(cell).inserted {
                            deductions.append(Deduction(action: .required(cell), reason: axis == 0 ? .rowRemaining(index) : .columnRemaining(index)))
                        }
                    }
                }
            }
            // Flood fill is an overestimate of reachable cells; the goal cannot be crossed.
            let tip = path.last!
            let used = Set(path.dropLast())
            var reachable: Set<Cell> = [tip]
            var pending = [tip]
            while let cell = pending.popLast() {
                if cell == puzzle.goal { continue }
                for next in neighbors(cell) where !excluded.contains(next) && !used.contains(next) {
                    if reachable.insert(next).inserted { pending.append(next) }
                }
            }
            guard required.subtracting(Set(path)).isSubset(of: reachable) else {
                return result(.contradiction("Uma casa obrigatória ou a casinha ficou sem ligação possível com a ponta do caminho. Revise as marcações ou desfaça um trecho."))
            }
            for cell in all where !required.contains(cell) && !excluded.contains(cell) && !reachable.contains(cell) {
                excluded.insert(cell)
                deductions.append(Deduction(action: .excluded(cell), reason: .unreachable))
            }
            let next = neighbors(tip).filter { !excluded.contains($0) && !path.contains($0) }
            if next.isEmpty { return result(.contradiction("A ponta do caminho ficou sem saída antes da casinha.")) }
            if next.count == 1 {
                path.append(next[0]); required.insert(next[0])
                deductions.append(Deduction(action: .extend(next[0]), reason: .onlyContinuation))
            }
            if deductions.count == before { return result(.stalled) }
        }
    }
}

public struct HintAdvice: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case deduction, conflict, unavailable, completed }
    public let kind: Kind
    public let text: String
    public let cells: Set<Cell>
    public let row: Int?
    public let column: Int?
}
public enum HintProvider {
    public static func advice(for game: Game) -> HintAdvice {
        let analysis = LogicEngine.analyze(puzzle: game.puzzle, prefix: game.path, marks: game.marks)
        if case .contradiction(let explanation) = analysis.outcome {
            return HintAdvice(kind: .conflict, text: explanation, cells: [], row: nil, column: nil)
        }
        if game.won { return HintAdvice(kind: .completed, text: "Margot já chegou! Todas as pistas foram atendidas.", cells: [], row: nil, column: nil) }
        // Only the FIRST fact is shown: later deductions may depend on simulated
        // intermediate facts/edges that the player has not established yet.
        guard let deduction = analysis.deductions.first else {
            return HintAdvice(kind: .unavailable, text: "Não encontrei uma próxima dedução com as regras disponíveis. Você pode revisar as pistas e suas marcações.", cells: [], row: nil, column: nil)
        }
        let cell: Cell
        let action: String
        switch deduction.action {
        case .required(let c): cell = c; action = "Esta casa precisa fazer parte da rota; isso ainda não desenha uma ligação até ela."
        case .excluded(let c): cell = c; action = "Você pode marcar esta casa com ×."
        case .extend(let c): cell = c; action = "Você pode continuar o caminho até esta casa."
        }
        var row: Int?
        var column: Int?
        switch deduction.reason {
        case .rowComplete(let r), .rowRemaining(let r): row = r
        case .columnComplete(let c), .columnRemaining(let c): column = c
        default: break
        }
        let assumption = game.marks.isEmpty ? "" : " Esta dica considera suas marcações × como hipóteses."
        return HintAdvice(kind: .deduction,
            text: "\(deduction.explanation) Linha \(cell.row+1), coluna \(cell.col+1): \(action)\(assumption)",
            cells: [cell], row: row, column: column)
    }
}

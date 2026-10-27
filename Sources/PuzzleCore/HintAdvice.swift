import Foundation
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
        if game.won { return HintAdvice(kind: .completed, text: String(localized: "Passeio concluído! Todas as pistas foram atendidas."), cells: [], row: nil, column: nil) }
        // Teach the simplest technique that applies: try counting before continuation, and so on.
        // Only the FIRST fact is shown: later deductions may depend on simulated
        // intermediate facts/edges that the player has not established yet.
        // A conflict anywhere in the player's marks comes first, before any fact.
        if case .contradiction(let explanation) = LogicEngine.analyze(puzzle: game.puzzle, prefix: game.path, marks: game.marks).outcome {
            return HintAdvice(kind: .conflict, text: explanation, cells: [], row: nil, column: nil)
        }
        let found = (1...LogicEngine.fullTier).lazy.compactMap {
            LogicEngine.analyze(puzzle: game.puzzle, prefix: game.path, marks: game.marks, maxTier: $0).deductions.first
        }.first
        guard let deduction = found else {
            return HintAdvice(kind: .unavailable, text: String(localized: "Não encontrei uma próxima dedução com as regras disponíveis. Você pode revisar as pistas e suas marcações."), cells: [], row: nil, column: nil)
        }
        let cell: Cell
        let action: String
        switch deduction.action {
        case .required(let c): cell = c; action = String(localized: "Ela faz parte do caminho.")
        case .excluded(let c): cell = c; action = String(localized: "Toque nela para marcar ×.")
        case .extend(let c): cell = c; action = String(localized: "Arraste o caminho até ela.")
        }
        var row: Int?
        var column: Int?
        switch deduction.reason {
        case .rowComplete(let r), .rowRemaining(let r): row = r
        case .columnComplete(let c), .columnRemaining(let c): column = c
        default: break
        }
        let assumption = game.marks.isEmpty ? "" : String(localized: " Esta dica considera suas marcações × como hipóteses.")
        return HintAdvice(kind: .deduction,
            text: String(localized: "Linha \(cell.row+1), coluna \(cell.col+1): \(deduction.explanation) \(action)\(assumption)"),
            cells: [cell], row: row, column: column)
    }
}

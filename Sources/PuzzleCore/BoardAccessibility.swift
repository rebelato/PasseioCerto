import Foundation

public enum BoardAccessibility {
    public static func label(_ cell: Cell) -> String {
        String(localized: "Linha \(cell.row+1), coluna \(cell.col+1)")
    }
    public static func value(game: Game, cell: Cell, dogName: String, highlighted: Bool = false) -> String {
        let state: String
        if cell == game.start {
            state = game.won ? String(localized: "Início do caminho concluído") : String(localized: "\(dogName), início do caminho")
        } else if cell == game.goal {
            state = game.won ? String(localized: "Casinha, passeio concluído") : game.path.last == cell ? String(localized: "Casinha conectada") : String(localized: "Casinha ainda não conectada")
        } else if game.puzzle.trees.contains(cell) { state = String(localized: "Árvore: o caminho precisa passar ao lado") }
        else if game.puzzle.cats.contains(cell) { state = String(localized: "Gato: o caminho não pode passar ao lado") }
        else if game.puzzle.obstacles.contains(cell) { state = String(localized: "Obstáculo") }
        else if game.path.contains(cell) { state = game.puzzle.bones.contains(cell) ? String(localized: "Osso, no caminho") : String(localized: "Caminho") }
        else if game.puzzle.bones.contains(cell) { state = String(localized: "Osso: o caminho precisa passar aqui") }
        else if game.marks.contains(cell) { state = String(localized: "Marcada com xis") }
        else { state = String(localized: "Livre") }
        var text = state + ". " + String(localized: "Linha: \(game.rowCounts[cell.row]) de \(game.rows[cell.row]). Coluna: \(game.columnCounts[cell.col]) de \(game.columns[cell.col]).")
        if let index = game.path.firstIndex(of: cell) {
            if index > 0 { text += " " + String(localized: "Vem de \(label(game.path[index-1])).") }
            if index+1 < game.path.count { text += " " + String(localized: "Segue para \(label(game.path[index+1])).") }
            else if !game.won { text += " " + String(localized: "Ponta atual do caminho.") }
        }
        if game.puzzle.puddles.contains(cell) { text += " " + String(localized: "Poça: só em linha reta.") }
        if game.puzzle.catZone.contains(cell) { text += " " + String(localized: "Ao lado do gato.") }
        if highlighted { text += " " + String(localized: "Casa destacada pela orientação.") }
        return text
    }
}

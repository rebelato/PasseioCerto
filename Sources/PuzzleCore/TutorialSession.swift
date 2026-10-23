import Foundation
import Combine

/// Each saved checkpoint rebuilds a tiny lesson, independently of the normal attempt.
@MainActor public final class TutorialSession: ObservableObject {
    public static let completedStep = 6
    public static let puzzle = try! Puzzle(puzzleID: "tutorial-v1", rows: [2,1,2], columns: [1,3,1], start: Cell(0,0), goal: Cell(2,2))
    @Published public private(set) var step: Int
    @Published public private(set) var game: Game
    @Published public private(set) var feedback: String?
    @Published public private(set) var hint: HintAdvice?
    public let dogName: String
    public init(step: Int, dogName: String = "Margot") {
        self.dogName = PlayerPreferences.normalizedName(dogName)
        let checkpoint = min(max(step, 0), Self.completedStep)
        self.step = checkpoint
        self.game = Self.setup(step: checkpoint)
    }
    public var instruction: String {
        switch step {
        case 0: String(localized: "\(dogName) e a casinha já contam nas pistas. A primeira linha pede 2 casas e já tem 1. Arraste de \(dogName) até a linha 1, coluna 2 para completá-la.")
        case 1: String(localized: "O caminho anda para os lados, para cima ou para baixo, nunca na diagonal. Continue arrastando até a linha 2, coluna 2.")
        case 2: String(localized: "A primeira linha já está completa. Toque na linha 1, coluna 3 para marcá-la com ×: um lembrete de que ela fica fora do caminho.")
        case 3: String(localized: "Uma marcação pode ser desfeita. Toque em Desfazer para remover o × que você acabou de colocar.")
        case 4: String(localized: "Uma dica explica uma dedução, sem jogar por você. Toque em Dica para experimentar.")
        case 5: String(localized: "Agora arraste até a casa: linha 3, coluna 2, e depois linha 3, coluna 3. A casa já conta na última pista!")
        default: String(localized: "Você aprendeu! No modo Desafiador são 3 vidas: passar do número de uma pista, pisar num arbusto ou cruzar o caminho custa uma. No Tranquilo, erre à vontade.")
        }
    }
    public var target: Cell? {
        switch step {
        case 0: Cell(0,1)
        case 1: Cell(1,1)
        case 2: Cell(0,2)
        case 5: game.path.last == Cell(2,1) ? Cell(2,2) : Cell(2,1)
        default: nil
        }
    }
    public func select(_ cell: Cell) {
        guard cell == target else {
            feedback = String(localized: "Siga a ação indicada acima. Aqui você pode aprender sem perder vidas."); return
        }
        game.play(cell, marking: step == 2)
        if step == 5 {
            if game.won { advance() }
        } else { advance() }
    }
    /// Taps mark ×; on drawing steps they get a nudge toward dragging.
    public func tap(_ cell: Cell) {
        if step == 2 { select(cell) }
        else if target != nil { feedback = String(localized: "Para desenhar, arraste a partir da ponta do caminho.") }
    }
    /// Cells crossed while dragging; only the indicated one counts.
    public func drag(to cell: Cell?) {
        guard step != 2, let cell, cell == target else { return }
        select(cell)
    }
    public func undo() {
        guard step == 3 else { return }
        game.undo()
        guard !game.marks.contains(Cell(0,2)) else { return }
        advance()
    }
    public func requestHint() {
        guard step == 4 else { return }
        hint = HintProvider.advice(for: game)
        advance()
    }
    private func advance() {
        step = min(step+1, Self.completedStep)
        feedback = nil
    }
    private static func setup(step: Int) -> Game {
        var game = Game(puzzle: puzzle)
        if step >= 1 { game.play(Cell(0,1)) }
        if step >= 2 { game.play(Cell(1,1)) }
        if step == 3 { game.play(Cell(0,2), marking: true) }
        if step >= completedStep { game.play(Cell(2,1)); game.play(Cell(2,2)) }
        return game
    }
}

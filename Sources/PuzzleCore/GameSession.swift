import Foundation
import Combine

@MainActor public final class GameSession: ObservableObject {
    @Published public private(set) var attempt: GameAttempt
    @Published public private(set) var stroke: GameStroke?
    @Published public private(set) var checking = false
    @Published public private(set) var message = "Cada tentativa tem 3 vidas. Um caminho impossível custa uma vida; × e desfazer são livres."
    @Published public private(set) var storageError: String?
    private var revision = 0
    private var worker: Task<MoveAssessment, Never>?
    private let saveURL: URL?
    private let nodeLimit: Int
    public var displayedGame: Game { stroke?.preview ?? attempt.game }
    public var canInteract: Bool { !checking && !attempt.defeated && !attempt.game.won }
    public init(attempt: GameAttempt = GameAttempt(), saveURL: URL? = nil, nodeLimit: Int = 100_000) {
        self.attempt = attempt; self.saveURL = saveURL; self.nodeLimit = nodeLimit
        if let saveURL, FileManager.default.fileExists(atPath: saveURL.path) {
            do { self.attempt = try JSONDecoder().decode(GameAttempt.self, from: Data(contentsOf: saveURL)) }
            catch { storageError = "Não foi possível recuperar a partida salva. O arquivo original foi preservado." }
        }
    }
    public func begin(at cell: Cell, marking: Bool) {
        guard canInteract, stroke == nil else { return }
        stroke = GameStroke(game: attempt.game, marking: marking)
        stroke?.move(to: cell)
    }
    public func move(to cell: Cell?) { guard !checking else { return }; stroke?.move(to: cell) }
    public func cancel() {
        revision += 1; worker?.cancel(); worker = nil; stroke = nil; checking = false
    }
    public func finish(cancelled: Bool = false) async {
        if cancelled { cancel(); return }
        guard let draft = stroke, !checking else { return }
        checking = true
        revision += 1
        let token = revision
        let before = attempt.game
        let limit = nodeLimit
        let task = Task.detached(priority: .userInitiated) {
            AttemptRules.assess(before: before, stroke: draft, nodeLimit: limit, isCancelled: { Task.isCancelled })
        }
        worker = task
        let assessment = await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
        guard token == revision else { return }
        if Task.isCancelled { cancel(); return }
        stroke = nil; worker = nil; checking = false
        switch assessment {
        case .accepted:
            attempt.game = draft.finish()
            message = attempt.game.won ? "Margot chegou! Todas as pistas foram atendidas." : "Continue seguindo as pistas."
            save()
        case .penalty:
            attempt.lives = max(0, attempt.lives-1)
            message = attempt.defeated ? "As vidas acabaram. Tente novamente com 3 vidas." : "Esse caminho não pode completar as pistas. Você perdeu 1 vida; a jogada foi desfeita."
            save()
        case .inconclusive: message = "Não foi possível verificar a jogada agora. Ela foi desfeita sem perder vida."
        case .cancelled: message = "Jogada cancelada sem perder vida."
        }
    }
    public func select(_ cell: Cell, marking: Bool) async {
        guard canInteract, stroke == nil else { return }
        begin(at: cell, marking: marking); await finish()
    }
    public func undo() {
        guard !checking, stroke == nil, !attempt.defeated, attempt.game.canUndo else { return }
        attempt.game.undo(); message = "Última ação desfeita. Vidas perdidas não são recuperadas."; save()
    }
    public func restart() {
        cancel(); attempt = GameAttempt(game: Game(puzzle: attempt.game.puzzle))
        message = "Nova tentativa: 3 vidas para levar a Margot até a casinha."; save()
    }
    public func replacePuzzle(_ puzzle: Puzzle) {
        cancel(); attempt = GameAttempt(game: Game(puzzle: puzzle)); save()
    }
    private func save() {
        // Do not overwrite an unreadable save implicitly.
        guard let saveURL, storageError == nil else { return }
        do {
            try FileManager.default.createDirectory(at: saveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(attempt).write(to: saveURL, options: .atomic)
        } catch { storageError = "Não foi possível salvar. A partida continua nesta sessão, mas pode não ser recuperada ao fechar." }
    }
}

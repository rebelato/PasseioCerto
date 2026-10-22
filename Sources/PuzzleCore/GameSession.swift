import Foundation
import Combine

@MainActor public final class GameSession: ObservableObject {
    @Published public private(set) var attempt: GameAttempt
    @Published public private(set) var stroke: GameStroke?
    @Published public private(set) var checking = false
    @Published public private(set) var message = "Cada tentativa tem 3 vidas. Um caminho impossível custa uma vida; × e desfazer são livres."
    @Published public private(set) var storageError: String?
    @Published public private(set) var preferences = PlayerPreferences()
    @Published public private(set) var tutorialStep = 0
    @Published public private(set) var completedPuzzleIDs: Set<String> = []
    @Published public private(set) var backupAvailable = false
    private var unreadableSave = false
    private var revision = 0
    private var worker: Task<MoveAssessment, Never>?
    private let saveURL: URL?
    private let nodeLimit: Int
    public var displayedGame: Game { stroke?.preview ?? attempt.game }
    public var canInteract: Bool { !checking && !attempt.defeated && !attempt.game.won }
    public init(attempt: GameAttempt = GameAttempt(), saveURL: URL? = nil, nodeLimit: Int = 100_000) {
        self.attempt = attempt; self.saveURL = saveURL; self.nodeLimit = nodeLimit
        if let saveURL, FileManager.default.fileExists(atPath: saveURL.path) {
            do {
                apply(try SaveStore(url: saveURL).load())
                message = self.attempt.defeated ? "As vidas acabaram. Tente novamente com 3 vidas." : self.attempt.game.won ? "Margot chegou! Partida concluída." : "Partida restaurada. Continue de onde parou."
            }
            catch {
                unreadableSave = true
                backupAvailable = (try? SaveStore(url: saveURL).loadBackup()) != nil
                storageError = "Não foi possível recuperar a partida salva. O arquivo original foi preservado."
            }
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
    public func setMarking(_ value: Bool) {
        guard !checking, stroke == nil else { return }
        preferences.marking = value; save()
    }
    public func setPreferences(_ value: PlayerPreferences) {
        guard !checking, stroke == nil else { return }
        preferences = value; save()
    }
    public func setTutorialStep(_ step: Int) {
        guard step >= 0 else { return }
        tutorialStep = step; save()
    }
    public func suspend() { cancel(); save() }
    public func retrySave() { save() }
    public func recoverBackup() {
        guard let saveURL else { return }
        cancel()
        do {
            let store = SaveStore(url: saveURL)
            let recovered = try store.loadBackup()
            try store.recover(recovered)
            apply(recovered); unreadableSave = false; storageError = nil; backupAvailable = false
            message = "Cópia anterior recuperada. O arquivo substituído foi preservado."
        } catch { storageError = "Não foi possível recuperar a cópia anterior. Os arquivos foram preservados." }
    }
    public func preserveOriginalAndSaveCurrent() {
        guard let saveURL else { return }
        cancel()
        do {
            try SaveStore(url: saveURL).recover(snapshot)
            unreadableSave = false; storageError = nil; backupAvailable = false
            message = "Partida atual salva. O arquivo original foi preservado separadamente."
        } catch { storageError = "Não foi possível salvar a recuperação. O arquivo original foi preservado." }
    }
    private var snapshot: PlayerSave {
        PlayerSave(attempt: attempt, preferences: preferences, tutorialStep: tutorialStep, completedPuzzleIDs: completedPuzzleIDs)
    }
    private func apply(_ saved: PlayerSave) {
        attempt = saved.attempt; preferences = saved.preferences
        tutorialStep = saved.tutorialStep; completedPuzzleIDs = saved.completedPuzzleIDs
    }
    private func save() {
        if attempt.game.won { completedPuzzleIDs.insert(attempt.game.puzzle.puzzleID) }
        guard let saveURL, !unreadableSave else { return }
        do {
            try SaveStore(url: saveURL).save(snapshot)
            storageError = nil
        } catch { storageError = "Não foi possível salvar. Você pode tentar novamente; a última gravação válida foi preservada." }
    }
}

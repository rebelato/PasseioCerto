import Foundation
import Combine

@MainActor public final class GameSession: ObservableObject {
    @Published public private(set) var attempt: GameAttempt
    @Published public private(set) var stroke: GameStroke?
    @Published public private(set) var checking = false
    /// Player-facing notice; nil when there is nothing worth saying.
    @Published public private(set) var message: String?
    @Published public private(set) var storageError: String?
    @Published public private(set) var preferences = PlayerPreferences()
    @Published public private(set) var tutorialStep = 0
    @Published public private(set) var completedPuzzleIDs: Set<String> = []
    @Published public private(set) var backupAvailable = false
    @Published public private(set) var activeDailyID: String?
    @Published public private(set) var parkedAttempts: [String: GameAttempt] = [:]
    @Published public private(set) var celebrating = false
    public func finishCelebration() { celebrating = false }
    @Published public private(set) var feedback: GameFeedback?
    private var unreadableSave = false
    @Published public private(set) var hint: HintAdvice?
    @Published public private(set) var hintChecking = false
    private var hintWorker: Task<HintAdvice, Never>?
    @Published public private(set) var generating = false
    private var generationWorker: Task<GenerationReport, Error>?
    public typealias GenerationService = @Sendable (UInt64, PuzzleDifficulty) async throws -> GenerationReport
    private let generate: GenerationService
    private var revision = 0
    private var worker: Task<MoveAssessment, Never>?
    private let saveURL: URL?
    private let nodeLimit: Int
    public var dogName: String { PlayerPreferences.normalizedName(preferences.dogName) }
    public var completedWalkCount: Int { completedPuzzleIDs.count }
    public func renameDog(_ name: String) {
        guard !generating, !checking, !hintChecking, stroke == nil else { return }
        preferences.dogName = PlayerPreferences.normalizedName(name)
        save()
    }
    public var displayedGame: Game { stroke?.preview ?? attempt.game }
    public var canInteract: Bool { !generating && !checking && !hintChecking && !attempt.defeated && !attempt.game.won }
    public init(attempt: GameAttempt = GameAttempt(), saveURL: URL? = nil, nodeLimit: Int = 100_000,
                generate: @escaping GenerationService = { seed, difficulty in
                    await PuzzleGenerator.generateAsync(seed: seed, difficulty: difficulty)
                }) {
        self.generate = generate
        self.attempt = attempt; self.saveURL = saveURL; self.nodeLimit = nodeLimit
        if let saveURL, FileManager.default.fileExists(atPath: saveURL.path) {
            do { apply(try SaveStore(url: saveURL).load()) }
            catch {
                unreadableSave = true
                backupAvailable = (try? SaveStore(url: saveURL).loadBackup()) != nil
                storageError = String(localized: "Não foi possível recuperar a partida salva. O arquivo original foi preservado.")
            }
        }
    }
    public func begin(at cell: Cell, marking: Bool) {
        guard canInteract, stroke == nil else { return }
        hint = nil
        stroke = GameStroke(game: attempt.game, marking: marking)
        stroke?.move(to: cell)
    }
    public func move(to cell: Cell?) { guard !checking else { return }; stroke?.move(to: cell) }
    public func cancel() {
        celebrating = false
        generationWorker?.cancel(); generationWorker = nil; generating = false
        revision += 1; worker?.cancel(); worker = nil; stroke = nil; checking = false
        hintWorker?.cancel(); hintWorker = nil; hint = nil; hintChecking = false
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
            celebrating = attempt.game.won
            if attempt.game.path != before.path || attempt.game.marks != before.marks {
                feedback = GameFeedback(attempt.game.won ? .victory : .action)
            }
            message = nil
            save()
        case .penalty:
            feedback = GameFeedback(.conflict)
            attempt.lives = max(0, attempt.lives-1)
            message = attempt.defeated ? String(localized: "As vidas acabaram. Tente novamente com 3 vidas.") : String(localized: "Esse caminho não pode completar as pistas. Você perdeu 1 vida; a jogada foi desfeita.")
            save()
        case .inconclusive: message = String(localized: "Não foi possível verificar a jogada agora. Ela foi desfeita sem perder vida.")
        case .cancelled: message = String(localized: "Jogada cancelada sem perder vida.")
        }
    }
    public func select(_ cell: Cell, marking: Bool) async {
        guard canInteract, stroke == nil else { return }
        begin(at: cell, marking: marking); await finish()
    }
    public func undo() {
        guard !generating, !checking, !hintChecking, stroke == nil, !attempt.defeated, !attempt.game.won, attempt.game.canUndo else { return }
        hint = nil
        attempt.game.undo(); feedback = GameFeedback(.action); message = nil; save()
    }
    public func restart() {
        cancel(); attempt = GameAttempt(game: Game(puzzle: attempt.game.puzzle))
        message = nil; save()
    }
    public func replacePuzzle(_ puzzle: Puzzle) {
        cancel(); parkCurrent(); activeDailyID = nil
        attempt = GameAttempt(game: Game(puzzle: puzzle)); save()
    }
    /// Keep the current attempt until a complete replacement is ready.
    public func newPuzzle(difficulty: PuzzleDifficulty, seed: UInt64 = UInt64.random(in: .min ... .max)) async {
        await generatePuzzle(difficulty: difficulty, seed: seed, dailyID: nil)
    }
    public func continueNormal() {
        guard activeDailyID != nil, let normal = parkedAttempts["normal"] else { return }
        cancel(); parkCurrent(); activeDailyID = nil; attempt = normal
        message = nil; save()
    }
    public func openDaily(date: Date = Date()) async {
        let daily = DailyChallenge(date: date)
        if activeDailyID == daily.id { cancel(); return }
        if let saved = parkedAttempts[daily.id] {
            cancel(); parkCurrent(); activeDailyID = daily.id; attempt = saved
            message = nil; save()
            return
        }
        await generatePuzzle(difficulty: .relaxed, seed: daily.seed, dailyID: daily.id)
    }
    private func parkCurrent() { parkedAttempts[activeDailyID ?? "normal"] = attempt }
    private func generatePuzzle(difficulty: PuzzleDifficulty, seed: UInt64, dailyID: String?) async {
        cancel()
        generating = true
        let token = revision
        let service = generate
        let task = Task.detached(priority: .userInitiated) { try await service(seed, difficulty) }
        generationWorker = task
        do {
            let report = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            guard token == revision else { return }
            generating = false; generationWorker = nil
            guard !Task.isCancelled, !task.isCancelled, report.outcome != .cancelled else {
                message = String(localized: "Geração cancelada. Sua partida foi mantida."); return
            }
            guard let puzzle = report.puzzle else {
                message = String(localized: "Não foi possível preparar a fase. Sua partida foi mantida; tente novamente."); return
            }
            let destination: Puzzle
            if let dailyID {
                destination = try Puzzle(puzzleID: dailyID, generatorVersion: puzzle.generatorVersion, seed: seed,
                    rows: puzzle.rows, columns: puzzle.columns, start: puzzle.start, goal: puzzle.goal, obstacles: puzzle.obstacles)
            } else { destination = puzzle }
            parkCurrent(); activeDailyID = dailyID
            // Reserve puzzles are verified like generated ones; the player never needs to know.
            attempt = GameAttempt(game: Game(puzzle: destination))
            message = nil
            save()
        } catch {
            guard token == revision else { return }
            generating = false; generationWorker = nil
            message = Task.isCancelled || task.isCancelled || error is CancellationError
                ? String(localized: "Geração cancelada. Sua partida foi mantida.")
                : String(localized: "Não foi possível preparar a fase. Sua partida foi mantida; tente novamente.")
        }
    }
    public func cancelGeneration() {
        guard generating else { return }
        cancel(); message = String(localized: "Geração cancelada. Sua partida foi mantida.")
    }
    public func requestHint() async {
        guard canInteract, stroke == nil else { return }
        hintChecking = true; hint = nil
        revision += 1
        let token = revision
        let current = attempt.game
        let task = Task.detached(priority: .userInitiated) { HintProvider.advice(for: current) }
        hintWorker = task
        let advice = await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
        guard revision == token else { return }
        hintChecking = false; hintWorker = nil
        if !Task.isCancelled && !task.isCancelled { hint = advice }
    }
    public func dismissHint() { hint = nil }
    public func setMarking(_ value: Bool) {
        guard !generating, !checking, !hintChecking, stroke == nil else { return }
        preferences.marking = value; save()
    }
    public func setPreferences(_ value: PlayerPreferences) {
        guard !generating, !checking, !hintChecking, stroke == nil else { return }
        preferences = value; preferences.dogName = PlayerPreferences.normalizedName(value.dogName); save()
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
            message = String(localized: "Cópia anterior recuperada. O arquivo substituído foi preservado.")
        } catch { storageError = String(localized: "Não foi possível recuperar a cópia anterior. Os arquivos foram preservados.") }
    }
    public func preserveOriginalAndSaveCurrent() {
        guard let saveURL else { return }
        cancel()
        do {
            try SaveStore(url: saveURL).recover(snapshot)
            unreadableSave = false; storageError = nil; backupAvailable = false
            message = String(localized: "Partida atual salva. O arquivo original foi preservado separadamente.")
        } catch { storageError = String(localized: "Não foi possível salvar a recuperação. O arquivo original foi preservado.") }
    }
    private var snapshot: PlayerSave {
        PlayerSave(attempt: attempt, preferences: preferences, tutorialStep: tutorialStep, completedPuzzleIDs: completedPuzzleIDs, activeDailyID: activeDailyID, parkedAttempts: parkedAttempts)
    }
    private func apply(_ saved: PlayerSave) {
        activeDailyID = saved.activeDailyID; parkedAttempts = saved.parkedAttempts
        attempt = saved.attempt; preferences = saved.preferences
        tutorialStep = saved.tutorialStep; completedPuzzleIDs = saved.completedPuzzleIDs
    }
    private func save() {
        if attempt.game.won { completedPuzzleIDs.insert(attempt.game.puzzle.puzzleID) }
        guard let saveURL, !unreadableSave else { return }
        do {
            try SaveStore(url: saveURL).save(snapshot)
            storageError = nil
        } catch { storageError = String(localized: "Não foi possível salvar. Você pode tentar novamente; a última gravação válida foi preservada.") }
    }
}

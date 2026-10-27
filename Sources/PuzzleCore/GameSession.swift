import Foundation
import Combine

@MainActor public final class GameSession: ObservableObject {
    @Published public private(set) var attempt: GameAttempt
    @Published public private(set) var stroke: GameStroke?
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
    /// Difficulty, a fresh variation number, and an optional fixed id (the daily challenge).
    public typealias WalkService = @Sendable (Difficulty, UInt64, String?) async throws -> GenerationReport
    private let generate: GenerationService
    private let generateWalk: WalkService
    @Published public private(set) var walks: [WalkRecord] = []
    private var revision = 0
    private let saveURL: URL?
    /// The last visible mistake, shown briefly on the board after the move is undone.
    @Published public private(set) var violation: StrokeViolation?
    private var violationWorker: Task<Void, Never>?
    public var displayedViolation: StrokeViolation? { stroke?.violation ?? violation }
    @Published public private(set) var bestPaws: [String: Int] = [:]
    /// Walks generated ahead of time, one per difficulty, so the next one starts instantly.
    private let prefetches: Bool
    private var prepared: [Difficulty: Puzzle] = [:]
    private var prefetchWorkers: [Difficulty: Task<Void, Never>] = [:]
    public var dogName: String { PlayerPreferences.normalizedName(preferences.dogName) }
    public var completedWalkCount: Int { completedPuzzleIDs.count }
    public func renameDog(_ name: String) {
        guard !generating, !hintChecking, stroke == nil else { return }
        preferences.dogName = PlayerPreferences.normalizedName(name)
        save()
    }
    public var displayedGame: Game { stroke?.preview ?? attempt.game }
    public var canInteract: Bool { !generating && !hintChecking && !attempt.defeated && !attempt.game.won }
    public init(attempt: GameAttempt = GameAttempt(), saveURL: URL? = nil, prefetches: Bool = false,
                generate: @escaping GenerationService = { seed, difficulty in
                    await PuzzleGenerator.generateAsync(seed: seed, difficulty: difficulty)
                },
                // The session already runs this off the main actor; nesting another detached task
                // here crashed the debug test host, so the default generates in place.
                generateWalk: @escaping WalkService = { WalkGenerator.generate($0, variation: $1, id: $2, isCancelled: { Task.isCancelled }) }) {
        self.generate = generate; self.generateWalk = generateWalk; self.prefetches = prefetches
        self.attempt = attempt; self.saveURL = saveURL
        if let saveURL, FileManager.default.fileExists(atPath: saveURL.path) {
            do { apply(try SaveStore(url: saveURL).load()) }
            catch {
                unreadableSave = true
                backupAvailable = (try? SaveStore(url: saveURL).loadBackup()) != nil
                storageError = String(localized: "Não foi possível recuperar a partida salva. O arquivo original foi preservado.")
            }
        }
        prefetch(preferences.difficulty)
    }
    public func begin(at cell: Cell, marking: Bool) {
        guard canInteract, stroke == nil else { return }
        hint = nil; clearViolation()
        stroke = GameStroke(game: attempt.game, marking: marking, solution: solution(for: attempt.game.puzzle))
        stroke?.move(to: cell)
    }
    private var solutionCache: (id: String, route: [Cell]?)?
    /// Computed once per grid; every step is checked against it.
    private func solution(for puzzle: Puzzle) -> [Cell]? {
        if let cached = solutionCache, cached.id == puzzle.puzzleID { return cached.route }
        let route = PuzzleSolution.route(for: puzzle)
        solutionCache = (puzzle.puzzleID, route)
        return route
    }
    public func move(to cell: Cell?) {
        guard let before = stroke?.preview, stroke?.move(to: cell) == true, let after = stroke?.preview,
              after.path.count > before.path.count else { return }
        feedback = GameFeedback(Self.metClues(after) > Self.metClues(before) ? .clueMet : .step)
    }
    public func cancel() {
        celebrating = false
        generationWorker?.cancel(); generationWorker = nil; generating = false
        revision += 1; stroke = nil; clearViolation()
        hintWorker?.cancel(); hintWorker = nil; hint = nil; hintChecking = false
    }
    public func finish(cancelled: Bool = false) async {
        if cancelled { cancel(); return }
        guard let draft = stroke else { return }
        let before = attempt.game
        stroke = nil
        switch AttemptRules.assess(stroke: draft, isCancelled: { Task.isCancelled }) {
        case .accepted:
            attempt.game = draft.finish()
            celebrating = attempt.game.won
            if attempt.game.won { recordWalk() }
            if attempt.game.path != before.path || attempt.game.marks != before.marks {
                feedback = GameFeedback(attempt.game.won ? .victory : .action)
            }
            message = nil
            save()
        case .penalty(let mistake):
            // The correct part of the stroke stays; only the wrong step is refused.
            attempt.game = draft.finish()
            penalize(mistake)
        case .cancelled: cancel()
        }
    }
    private func penalize(_ mistake: StrokeViolation) {
        feedback = GameFeedback(.conflict)
        attempt.mistakes += 1
        show(mistake)
        message = mistake.explanation + (attempt.defeated ? String(localized: " As vidas acabaram.") : String(localized: " −1 vida."))
        save()
    }
    /// The mistake stays highlighted for a moment so the player sees what went wrong.
    private func show(_ mistake: StrokeViolation) {
        violationWorker?.cancel()
        violation = mistake
        violationWorker = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, self?.violation == mistake else { return }
            self?.violation = nil
        }
    }
    private func clearViolation() { violationWorker?.cancel(); violationWorker = nil; violation = nil }
    /// Every tap is an attempt: beside the tip it is a step, and anywhere off the solution it
    /// costs a life. A tap on a solution cell that is not next yet does nothing. Holding toggles ×,
    /// which is always free. Steps are never undone.
    public func tap(_ cell: Cell, held: Bool = false) async {
        guard canInteract, stroke == nil else { return }
        let game = attempt.game
        if held { await select(cell, marking: true); return }
        guard game.puzzle.contains(cell), !game.path.contains(cell), !game.puzzle.blocked.contains(cell) else { return }
        let besideTip = game.path.last.map { abs($0.row-cell.row) + abs($0.col-cell.col) == 1 } ?? false
        if besideTip && !game.marks.contains(cell) { await select(cell, marking: false); return }
        if let route = solution(for: game.puzzle), !route.contains(cell) {
            hint = nil; clearViolation()
            penalize(StrokeViolation(kind: .offRoute, cell: cell))
        }
    }
    public func select(_ cell: Cell, marking: Bool) async {
        guard canInteract, stroke == nil else { return }
        begin(at: cell, marking: marking); await finish()
    }
    /// Drops a stroke in progress without judging it (a pinch started over the board).
    public func dropStroke() {
        guard stroke != nil else { return }
        stroke = nil; clearViolation()
    }
    public func undo() {
        guard !generating, !hintChecking, stroke == nil, !attempt.defeated, !attempt.game.won, attempt.game.canUndo else { return }
        hint = nil
        attempt.game.undo(); feedback = GameFeedback(.action); message = nil; save()
    }
    public func restart() {
        cancel(); attempt = GameAttempt(game: Game(puzzle: attempt.game.puzzle), difficulty: attempt.difficulty)
        message = nil; save()
    }
    public func replacePuzzle(_ puzzle: Puzzle) {
        cancel(); parkCurrent(); activeDailyID = nil
        attempt = GameAttempt(game: Game(puzzle: puzzle)); save()
    }
    /// Keep the current attempt until a complete replacement is ready.
    public func newPuzzle(difficulty: PuzzleDifficulty, seed: UInt64 = UInt64.random(in: .min ... .max)) async {
        let service = generate
        await prepare(dailyID: nil, difficulty: nil) { try await service(seed, difficulty) }
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
        let service = generateWalk
        await prepare(dailyID: daily.id, difficulty: nil) { try await service(DailyChallenge.difficulty, daily.seed, daily.id) }
    }
    private func parkCurrent() { parkedAttempts[activeDailyID ?? "normal"] = attempt }
    /// Jogar: resume the unfinished normal walk at the chosen difficulty, or start a new one.
    public func play() async {
        if activeDailyID != nil { continueNormal() }
        guard activeDailyID == nil else { return }
        let current = attempt.difficulty ?? (attempt.game.puzzle.rows.count == preferences.difficulty.size ? preferences.difficulty : nil)
        if attempt.game.won || attempt.defeated || current != preferences.difficulty { await play(preferences.difficulty) }
    }
    /// A brand-new grid at this difficulty; only the daily challenge ever repeats.
    public func play(_ difficulty: Difficulty, variation: UInt64 = UInt64.random(in: 1 ... .max)) async {
        if let ready = prepared.removeValue(forKey: difficulty) {
            cancel(); parkCurrent(); activeDailyID = nil
            attempt = GameAttempt(game: Game(puzzle: ready), difficulty: difficulty)
            message = nil; save()
            prefetch(difficulty)
            return
        }
        let service = generateWalk
        await prepare(dailyID: nil, difficulty: difficulty) { try await service(difficulty, variation, nil) }
    }
    /// Próximo passeio: another walk at the same difficulty.
    public func playNext() async { await play(attempt.difficulty ?? preferences.difficulty) }
    /// Outra fase / Tentar de novo / Jogar de novo: a new grid of the same difficulty. The daily
    /// challenge restarts instead, and older free walks get a new walk at the chosen difficulty.
    public func replay() async {
        if activeDailyID != nil { restart() }
        else { await playNext() }
    }
    public func setDifficulty(_ difficulty: Difficulty) {
        guard !generating, !hintChecking, stroke == nil else { return }
        preferences.difficulty = difficulty; save()
        prefetch(difficulty)
    }
    /// Generates a walk in the background so the next play at this difficulty is instant.
    private func prefetch(_ difficulty: Difficulty) {
        guard prefetches, prepared[difficulty] == nil, prefetchWorkers[difficulty] == nil else { return }
        let service = generateWalk
        prefetchWorkers[difficulty] = Task { [weak self] in
            let report = try? await Task.detached(priority: .utility) {
                try await service(difficulty, UInt64.random(in: 1 ... .max), nil)
            }.value
            guard let self else { return }
            self.prefetchWorkers[difficulty] = nil
            if let puzzle = report?.puzzle { self.prepared[difficulty] = puzzle }
        }
    }
    private func prepare(dailyID: String?, difficulty: Difficulty?, _ work: @escaping @Sendable () async throws -> GenerationReport) async {
        cancel()
        generating = true
        let token = revision
        let task = Task.detached(priority: .userInitiated) { try await work() }
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
            parkCurrent(); activeDailyID = dailyID
            // Reserve puzzles are verified like generated ones; the player never needs to know.
            attempt = GameAttempt(game: Game(puzzle: puzzle), difficulty: difficulty)
            message = nil
            save()
            if let difficulty { prefetch(difficulty) }
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
        guard !generating, !hintChecking, stroke == nil else { return }
        preferences.marking = value; save()
    }
    public func setPreferences(_ value: PlayerPreferences) {
        guard !generating, !hintChecking, stroke == nil else { return }
        preferences = value; preferences.dogName = PlayerPreferences.normalizedName(value.dogName); save()
    }
    private static func metClues(_ game: Game) -> Int {
        let rows = zip(game.rowCounts, game.rows).filter { $0.0 == $0.1 }.count
        let columns = zip(game.columnCounts, game.columns).filter { $0.0 == $0.1 }.count
        return rows + columns
    }
    public var totalPaws: Int { bestPaws.values.reduce(0, +) }
    public func dailyStreak(today: Date = Date()) -> Int {
        DailyChallenge.streak(completed: completedPuzzleIDs, today: today)
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
        PlayerSave(attempt: attempt, preferences: preferences, tutorialStep: tutorialStep, completedPuzzleIDs: completedPuzzleIDs, activeDailyID: activeDailyID, parkedAttempts: parkedAttempts, bestPaws: bestPaws,
                   walks: walks)
    }
    /// A finished walk joins the album (replays replace the older photo).
    private func recordWalk() {
        let game = attempt.game
        walks.removeAll { $0.puzzle.puzzleID == game.puzzle.puzzleID }
        walks.append(WalkRecord(puzzle: game.puzzle, path: game.path, paws: attempt.paws, date: Date(),
                                difficulty: attempt.difficulty ?? (activeDailyID != nil ? DailyChallenge.difficulty : nil)))
        if walks.count > WalkRecord.albumLimit { walks.removeFirst(walks.count - WalkRecord.albumLimit) }
    }
    public var unlockedAccessories: [Accessory] { Accessory.allCases.filter { $0.cost <= totalPaws } }
    public func wear(_ accessory: Accessory?) {
        guard accessory.map(unlockedAccessories.contains) ?? true else { return }
        preferences.accessory = accessory; save()
    }
    private func apply(_ saved: PlayerSave) {
        activeDailyID = saved.activeDailyID; parkedAttempts = saved.parkedAttempts
        attempt = saved.attempt; preferences = saved.preferences
        tutorialStep = saved.tutorialStep; completedPuzzleIDs = saved.completedPuzzleIDs; bestPaws = saved.bestPaws
        walks = saved.walks
    }
    private func save() {
        if attempt.game.won {
            let id = attempt.game.puzzle.puzzleID
            completedPuzzleIDs.insert(id)
            bestPaws[id] = max(bestPaws[id] ?? 0, attempt.paws)
        }
        guard let saveURL, !unreadableSave else { return }
        do {
            try SaveStore(url: saveURL).save(snapshot)
            storageError = nil
        } catch { storageError = String(localized: "Não foi possível salvar. Você pode tentar novamente; a última gravação válida foi preservada.") }
    }
}

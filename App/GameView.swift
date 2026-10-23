import SwiftUI

struct GameView: View {
    @StateObject private var session = GameSession(saveURL: URL.applicationSupportDirectory.appending(path: "PasseioCerto/attempt.json"))
    private var game: Game { session.attempt.game }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrivalProgress = 0.0
    @State private var showingHome = true
    @State private var showingLearning = false
    @State private var tutorialRequested = false
    @AccessibilityFocusState private var victoryFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    private var marking: Bool { session.preferences.marking }
    private var markingBinding: Binding<Bool> {
        Binding(get: { session.preferences.marking }, set: { session.setMarking($0) })
    }
    @AccessibilityFocusState private var hintFocused: Bool
    @AccessibilityFocusState private var hintButtonFocused: Bool
    @State private var feedbackPlayer = GameFeedbackPlayer()
    @State private var nameDraft = ""
    @State private var recovery = false
    @State private var reset = false
    @State private var newPuzzle = false
    @State private var difficulty = PuzzleDifficulty.relaxed
    @ScaledMetric(relativeTo: .headline) private var cellMinimum: CGFloat = 48
    private var displayedGame: Game { session.displayedGame }
    private let green = GardenTheme.accent
    var body: some View {
        gameContent
        .onChange(of: session.feedback) { _, event in
            guard let event, scenePhase == .active, !showingHome, !showingLearning else { return }
            feedbackPlayer.play(event.kind, preferences: session.preferences)
        }
        .onChange(of: session.preferences.soundEnabled) { _, enabled in if !enabled { feedbackPlayer.stop() } }
        .onChange(of: showingLearning) { _, visible in if visible { feedbackPlayer.stop() } }
        .onChange(of: showingHome) { _, visible in if visible { feedbackPlayer.stop() } }
        .onDisappear { feedbackPlayer.stop(); session.suspend() }
    }
    private var gameContent: some View {
        Group {
        if showingHome {
            home
        } else {
        GeometryReader { screen in
        let side = max((min(screen.size.width, 420) - 32) / CGFloat(game.columns.count + 1), cellMinimum)
        ScrollView {
            VStack(spacing: GardenTheme.spacing) {
                Text(String(localized: "Passeio Certo")).font(GardenTheme.title).foregroundStyle(GardenTheme.ink)
                Button(String(localized: "Início"), systemImage: "house") { session.suspend(); showingHome = true }
                    .buttonStyle(GardenButtonStyle())
                Button(String(localized: "Ajustes"), systemImage: "gearshape") {
                    session.suspend(); tutorialRequested = false; showingLearning = true
                }.buttonStyle(GardenButtonStyle())
                Text(session.activeDailyID.map { String(localized: "Desafio diário · ") + $0.replacingOccurrences(of: "daily-v1-", with: "") } ?? String(localized: "Praça das Flores · 5 × 5")).font(.subheadline)
                HStack(spacing: 10) {
                    ForEach(0..<3) { index in
                        Image(systemName: index < session.attempt.lives ? "heart.fill" : "heart")
                            .foregroundStyle(GardenTheme.terracotta).font(.title3)
                    }
                    Text(String(localized: "\(session.attempt.lives) de 3 vidas")).font(.subheadline)
                }.accessibilityElement(children: .ignore)
                    .accessibilityLabel(session.attempt.lives == 1 ? String(localized: "1 vida restante de 3") : String(localized: "\(session.attempt.lives) vidas restantes de 3"))
                HStack(spacing: 12) {
                    Puppy(pose: game.won ? .happy : .idle).frame(width: 52, height: 52)
                    Text(displayedGame.won ? String(localized: "Chegamos em casa!") : String(localized: "Leve \(session.dogName) até a casinha"))
                        .font(GardenTheme.heading).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(GardenTheme.sage, in: RoundedRectangle(cornerRadius: GardenTheme.radius))
                ScrollView(.horizontal) {
                    PuzzleBoard(game: displayedGame, cellSide: side,
                        marking: marking, interactionsEnabled: session.canInteract,
                        onSelectMode: { cell, marking in Task { await session.select(cell, marking: marking) } }, dogName: session.dogName,
                        arrivalProgress: game.won ? (session.celebrating ? arrivalProgress : 1) : 0,
                        walking: session.celebrating && !reduceMotion,
                        highlighted: session.hint?.cells ?? [], highlightedRow: session.hint?.row,
                        highlightedColumn: session.hint?.column, onSelect: select,
                        onStrokeStart: { session.begin(at: $0, marking: marking) },
                        onStrokeMove: { session.move(to: $0) },
                        onStrokeEnd: finishStroke)
                        .allowsHitTesting(session.canInteract)
                        .accessibilityHidden(session.attempt.defeated)
                }.frame(height: CGFloat(game.rows.count + 1) * side)
                if let message = session.message { GardenNote(text: message, symbol: "info.circle") }
                if let hint = session.hint {
                    VStack(alignment: .leading, spacing: 8) {
                        GardenNote(text: hint.text, symbol: hint.kind == .conflict ? "exclamationmark.triangle" : "lightbulb")
                            .accessibilityFocused($hintFocused)
                        Button(String(localized: "Fechar dica"), systemImage: "xmark.circle") { session.dismissHint(); hintFocused = false; hintButtonFocused = true }
                            .buttonStyle(GardenButtonStyle())
                    }
                }
                if session.generating {
                    ProgressView(String(localized: "Preparando novo passeio…"))
                    Button(String(localized: "Cancelar geração"), systemImage: "xmark.circle") { session.cancelGeneration() }
                        .buttonStyle(GardenButtonStyle())
                }
                if session.hintChecking { ProgressView(String(localized: "Preparando dica…")) }
                if session.checking { ProgressView(String(localized: "Verificando jogada…")) }
                if let error = session.storageError {
                    GardenNote(text: error, symbol: "exclamationmark.triangle")
                    VStack {
                        if session.backupAvailable {
                            Button(String(localized: "Recuperar cópia anterior")) { session.recoverBackup() }
                        }
                        Button(String(localized: "Tentar salvar novamente")) { session.retrySave() }
                        Button(String(localized: "Salvar esta partida preservando o arquivo original")) { recovery = true }
                    }.buttonStyle(GardenButtonStyle())
                }
                if session.attempt.defeated {
                    Button(String(localized: "Tentar novamente"), systemImage: "arrow.clockwise") { session.restart() }
                        .buttonStyle(GardenButtonStyle())
                }
                if game.won {
                    VStack(spacing: 12) {
                        Label(String(localized: "Passeio concluído!"), systemImage: "heart.fill")
                            .font(GardenTheme.heading).foregroundStyle(GardenTheme.accent)
                            .accessibilityFocused($victoryFocused)
                        Text(String(localized: "Você levou \(session.dogName) para casa. Obrigada pelo passeio!"))
                            .multilineTextAlignment(.center)
                        if session.celebrating {
                            Button(String(localized: "Pular animação")) { session.finishCelebration() }
                        }
                        Button(String(localized: "Jogar novamente"), systemImage: "arrow.clockwise") { session.restart() }
                        Button(String(localized: "Voltar ao início"), systemImage: "house") {
                            session.suspend(); showingHome = true
                        }
                    }.buttonStyle(GardenButtonStyle()).padding(16)
                        .frame(maxWidth: .infinity)
                        .background(GardenTheme.sage, in: RoundedRectangle(cornerRadius: GardenTheme.radius))
                        .disabled(session.generating)
                } else {
                GardenTools(marking: markingBinding).disabled(session.generating || session.stroke != nil || session.checking || session.hintChecking || session.attempt.defeated)
                HStack {
                    Button(String(localized: "Desfazer"), systemImage: "arrow.uturn.backward") { session.undo() }.disabled(!game.canUndo)
                    Button(String(localized: "Dica"), systemImage: "lightbulb") {
                        Task { await session.requestHint() }
                    }.disabled(!session.canInteract).accessibilityFocused($hintButtonFocused)
                }.buttonStyle(GardenButtonStyle()).disabled(session.generating || session.stroke != nil || session.checking || session.hintChecking || session.attempt.defeated)
                HStack {
                    Button(String(localized: "Reiniciar"), systemImage: "arrow.clockwise") { reset = true }
                }.buttonStyle(GardenButtonStyle()).disabled(session.generating || session.stroke != nil || session.checking || session.hintChecking || session.attempt.defeated)
                }
                DifficultyPicker(selection: $difficulty).disabled(session.generating)
                Button(game.won ? String(localized: "Próxima fase") : String(localized: "Nova fase"), systemImage: "sparkles") { newPuzzle = true }
                    .buttonStyle(GardenButtonStyle())
                    .disabled(session.generating || session.checking || session.hintChecking || session.stroke != nil)
                Text(String(localized: "Arraste ou toque nas casas vizinhas. Volte uma casa para apagar. Para rolar, arraste pelas pistas ou fora da grade.")).font(.footnote).foregroundStyle(.secondary)
            }.padding(GardenTheme.spacing).frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
        }.background(GardenTheme.background).foregroundStyle(GardenTheme.ink).tint(green)
            .confirmationDialog(String(localized: "Reiniciar esta fase?"), isPresented: $reset, titleVisibility: .visible) {
                Button(String(localized: "Reiniciar"), role: .destructive) { session.restart() }
            }
        }
        }
        }
        .task {
            if session.tutorialStep < TutorialSession.completedStep {
                tutorialRequested = true; showingLearning = true
            }
        }
        .sheet(isPresented: $showingLearning) {
            if tutorialRequested {
                TutorialView(step: session.tutorialStep, dogName: session.dogName,
                    onProgress: { session.setTutorialStep($0) },
                    onClose: { showingLearning = false; showingHome = false })
            } else {
                settings
            }
        }
        .task(id: session.celebrating) {
            guard session.celebrating else { arrivalProgress = 0; return }
            if reduceMotion { session.finishCelebration(); return }
            arrivalProgress = 0
            // Give the start position a render pass before beginning the route.
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: 2)) { arrivalProgress = 1 }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard !Task.isCancelled else { return }
            session.finishCelebration()
        }
        .onChange(of: reduceMotion) { _, enabled in if enabled { session.finishCelebration() } }
        .onChange(of: game.won) { _, won in victoryFocused = won }
        .confirmationDialog(String(localized: "Gerar um novo passeio normal? O passeio normal anterior será substituído quando estiver pronto. Desafios diários ficam guardados."), isPresented: $newPuzzle, titleVisibility: .visible) {
            Button(String(localized: "Gerar fase · \(difficulty.title)")) {
                Task {
                    let previous = game.puzzle.puzzleID
                    await session.newPuzzle(difficulty: difficulty)
                    if game.puzzle.puzzleID != previous { showingHome = false }
                }
            }
        }
        .confirmationDialog(String(localized: "Salvar esta partida no lugar da anterior? O arquivo anterior será guardado separadamente."), isPresented: $recovery, titleVisibility: .visible) {
            Button(String(localized: "Preservar original e salvar esta partida")) { session.preserveOriginalAndSaveCurrent() }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { feedbackPlayer.stop(); session.suspend() } }
        .onChange(of: session.hint) { _, value in hintFocused = value != nil }
        .onChange(of: marking) { _, _ in finishStroke(true) }
    }
    private var settings: some View {
                ScrollView {
                VStack(spacing: 24) {
                    Text(String(localized: "Ajustes")).font(GardenTheme.title)
                    Toggle(String(localized: "Sons"), isOn: preferenceBinding(\.soundEnabled))
                    Toggle(String(localized: "Feedback tátil"), isOn: preferenceBinding(\.hapticsEnabled))
                    Text(String(localized: "Sons suaves e vibrações opcionais. As pistas e mensagens continuam disponíveis com tudo desligado."))
                        .font(.footnote).foregroundStyle(.secondary)
                    DisclosureGroup(String(localized: "Como jogar")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(localized: "Ligue a cachorrinha à casa por casas vizinhas, sem diagonais nem repetir casas."))
                            Text(String(localized: "As pistas contam as casas ocupadas em cada linha e coluna, incluindo o início e a casa. Uma pista atendida não garante que o caminho inteiro esteja correto."))
                            Text(String(localized: "Use × como lembrete. Desfazer remove sua última ação; Dica explica uma dedução sem jogar por você."))
                            Text(String(localized: "Você tem 3 vidas. Um caminho impossível custa uma vida e é desfeito. ×, desfazer e gestos inválidos não custam vidas; desfazer não devolve vidas perdidas."))
                        }.fixedSize(horizontal: false, vertical: true).padding(.top, 8)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "Nome da sua companhia")).font(GardenTheme.heading)
                        TextField("Margot", text: $nameDraft).textFieldStyle(.roundedBorder)
                            .accessibilityLabel(String(localized: "Nome da cachorrinha"))
                            .onSubmit { session.renameDog(nameDraft); nameDraft = session.dogName }
                        Text(String(localized: "Até 24 caracteres. Em branco, usamos Margot.")).font(.footnote)
                        Button(String(localized: "Salvar nome")) { session.renameDog(nameDraft); nameDraft = session.dogName }
                            .buttonStyle(GardenButtonStyle())
                        Text(String(localized: "Nome atual: \(session.dogName)")).fixedSize(horizontal: false, vertical: true)
                        if let error = session.storageError { GardenNote(text: error, symbol: "exclamationmark.triangle") }
                    }
                    Button(session.tutorialStep < TutorialSession.completedStep ? String(localized: "Continuar tutorial") : String(localized: "Repetir tutorial")) {
                        if session.tutorialStep >= TutorialSession.completedStep { session.setTutorialStep(0) }
                        tutorialRequested = true
                    }.buttonStyle(GardenButtonStyle())
                    Button(String(localized: "Fechar")) { showingLearning = false }.buttonStyle(GardenButtonStyle())
                }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(GardenTheme.background)
                }.background(GardenTheme.background).onAppear { nameDraft = session.dogName }
    }
    private func preferenceBinding(_ keyPath: WritableKeyPath<PlayerPreferences, Bool>) -> Binding<Bool> {
        Binding(get: { session.preferences[keyPath: keyPath] }, set: { value in
            var preferences = session.preferences
            preferences[keyPath: keyPath] = value
            session.setPreferences(preferences)
        })
    }
    private var home: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let daily = DailyChallenge(date: timeline.date)
            ScrollView {
                VStack(spacing: 20) {
                    Puppy().frame(width: 110, height: 110)
                    Text(String(localized: "Passeio Certo")).font(GardenTheme.title)
                    Text(String(localized: "Um passeio de cada vez, com \(session.dogName).")).multilineTextAlignment(.center)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "Seu cantinho")).font(GardenTheme.heading)
                        Text(session.completedWalkCount == 1 ? String(localized: "1 passeio diferente concluído") : String(localized: "\(session.completedWalkCount) passeios diferentes concluídos"))
                            .font(.headline).fixedSize(horizontal: false, vertical: true)
                        Label(session.dogName, systemImage: "pawprint.fill")
                            .fixedSize(horizontal: false, vertical: true)
                        Label(String(localized: "Praça das Flores"), systemImage: "leaf.fill")
                        Text(String(localized: "Repetir uma fase não aumenta a contagem.")).font(.footnote).foregroundStyle(.secondary)
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(GardenTheme.sage, in: RoundedRectangle(cornerRadius: GardenTheme.radius))
                    Button(String(localized: "Continuar"), systemImage: "play.fill") { showingHome = false }
                    if session.activeDailyID != nil {
                        Button(String(localized: "Voltar ao passeio normal")) { session.continueNormal(); showingHome = false }
                    }
                    DifficultyPicker(selection: $difficulty)
                    Button(String(localized: "Novo passeio"), systemImage: "sparkles") { newPuzzle = true }
                    Button(session.completedPuzzleIDs.contains(daily.id) ? String(localized: "Desafio do dia · concluído") : String(localized: "Desafio do dia"), systemImage: "calendar") {
                        Task {
                            await session.openDaily(date: timeline.date)
                            if session.activeDailyID == daily.id { showingHome = false }
                        }
                    }
                    Text(String(localized: "Novo desafio em \(DailyCountdown.text(from: timeline.date))"))
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button(String(localized: "Ajustes"), systemImage: "gearshape") {
                        tutorialRequested = false; showingLearning = true
                    }
                }.buttonStyle(GardenButtonStyle()).disabled(session.generating)
                if session.generating {
                    ProgressView(String(localized: "Preparando passeio…"))
                    Button(String(localized: "Cancelar")) { session.cancelGeneration() }.buttonStyle(GardenButtonStyle())
                }
                if let error = session.storageError {
                    GardenNote(text: error + String(localized: " Abra Continuar para acessar a recuperação."), symbol: "exclamationmark.triangle")
                }
            }.padding(20).frame(maxWidth: 420).frame(maxWidth: .infinity)
                .background(GardenTheme.background).foregroundStyle(GardenTheme.ink)
        }
    }
    private enum DailyCountdown {
        /// "3h 12min" until the next local midnight; minutes only in the last hour.
        static func text(from now: Date) -> String {
            let minutes = max(1, Int(DailyChallenge.nextReset(after: now).timeIntervalSince(now) / 60))
            return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)min" : "\(minutes)min"
        }
    }
    private func finishStroke(_ cancelled: Bool) {
        if cancelled { session.cancel() }
        else { Task { await session.finish() } }
    }
    private func select(_ cell: Cell) {
        Task { await session.select(cell, marking: marking) }
    }
}


private struct TutorialView: View {
    @StateObject private var lesson: TutorialSession
    let onProgress: (Int) -> Void
    let onClose: () -> Void
    @ScaledMetric(relativeTo: .headline) private var side: CGFloat = 60
    @AccessibilityFocusState private var instructionFocused: Bool
    init(step: Int, dogName: String, onProgress: @escaping (Int) -> Void, onClose: @escaping () -> Void) {
        _lesson = StateObject(wrappedValue: TutorialSession(step: step, dogName: dogName))
        self.onProgress = onProgress; self.onClose = onClose
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(String(localized: "Primeiro passeio")).font(GardenTheme.title)
                Text(lesson.step < TutorialSession.completedStep ? String(localized: "Passo \(lesson.step+1) de 6") : String(localized: "Tudo pronto!")).font(.subheadline)
                GardenNote(text: lesson.instruction, symbol: "pawprint")
                    .accessibilityFocused($instructionFocused)
                ScrollView(.horizontal) {
                    PuzzleBoard(game: lesson.game, cellSide: side, marking: lesson.step == 2, interactionsEnabled: lesson.target != nil, dogName: lesson.dogName,
                        arrivalProgress: lesson.game.won ? 1 : 0,
                        highlighted: lesson.target.map { Set([$0]) } ?? [],
                        onSelect: { lesson.select($0) },
                        onStrokeStart: { lesson.select($0) })
                }.frame(height: side*4)
                if let feedback = lesson.feedback { GardenNote(text: feedback, symbol: "info.circle") }
                if let hint = lesson.hint { GardenNote(text: hint.text, symbol: "lightbulb") }
                if lesson.step == 2 { Text(String(localized: "Ferramenta × selecionada para este exercício.")).font(.footnote) }
                if lesson.step == 3 {
                    Button(String(localized: "Desfazer"), systemImage: "arrow.uturn.backward") { lesson.undo() }
                }
                if lesson.step == 4 {
                    Button(String(localized: "Dica"), systemImage: "lightbulb") { lesson.requestHint() }
                }
                if lesson.step == TutorialSession.completedStep {
                    Button(String(localized: "Ir para meu passeio"), systemImage: "pawprint") { onClose() }
                } else {
                    Button(String(localized: "Continuar depois")) { onClose() }
                    Button(String(localized: "Pular tutorial")) {
                        onProgress(TutorialSession.completedStep); onClose()
                    }
                }
            }.buttonStyle(GardenButtonStyle()).padding(20).frame(maxWidth: 420).frame(maxWidth: .infinity)
        }.background(GardenTheme.background).foregroundStyle(GardenTheme.ink)
            .interactiveDismissDisabled()
            .onChange(of: lesson.step) { _, step in onProgress(step); instructionFocused = true }
            .onAppear { instructionFocused = true }
    }
}

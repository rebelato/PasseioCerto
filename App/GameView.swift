import SwiftUI

struct GameView: View {
    @StateObject private var session = GameSession(saveURL: URL.applicationSupportDirectory.appending(path: "PasseioCerto/attempt.json"))
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingHome = true
    @State private var showingLearning = false
    @State private var tutorialRequested = false
    @State private var feedbackPlayer = GameFeedbackPlayer()
    @State private var nameDraft = ""
    var body: some View {
        Group {
            if showingHome {
                home
            } else {
                GameScreen(session: session, title: walkTitle,
                    onHome: { session.suspend(); showingHome = true },
                    onSettings: { session.suspend(); tutorialRequested = false; showingLearning = true },
                    onNext: { Task { await session.newPuzzle(difficulty: .relaxed) } },
                    onArrive: { feedbackPlayer.play(.victory, preferences: session.preferences) })
            }
        }
        .background(GardenTheme.background)
        .onChange(of: session.feedback) { _, event in
            guard let event, scenePhase == .active, !showingHome, !showingLearning else { return }
            // With motion on, the success haptic waits for Margot to reach the house.
            if event.kind == .victory && !reduceMotion { return }
            feedbackPlayer.play(event.kind, preferences: session.preferences)
        }
        .onChange(of: session.preferences.soundEnabled) { _, enabled in if !enabled { feedbackPlayer.stop() } }
        .onChange(of: showingLearning) { _, visible in if visible { feedbackPlayer.stop() } }
        .onChange(of: showingHome) { _, visible in if visible { feedbackPlayer.stop() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { feedbackPlayer.stop(); session.suspend() } }
        .onDisappear { feedbackPlayer.stop(); session.suspend() }
        .task {
            // Screenshot checks: `simctl launch … -PCOpenWalk YES` skips the home screen.
            if UserDefaults.standard.bool(forKey: "PCOpenWalk") { showingHome = false }
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
    }
    private var walkTitle: String {
        session.activeDailyID != nil ? String(localized: "Desafio do dia") : String(localized: "Praça das Flores")
    }

    // MARK: Home

    /// One filled call to action (Jogar) and one daily card; everything else is secondary.
    private var home: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let daily = DailyChallenge(date: timeline.date)
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Spacer()
                        Button { tutorialRequested = false; showingLearning = true } label: {
                            Image(systemName: "gearshape").font(.title3)
                        }.frame(width: GardenTheme.minTarget, height: GardenTheme.minTarget)
                            .accessibilityLabel(String(localized: "Ajustes"))
                    }
                    Puppy().frame(width: 110, height: 110)
                    VStack(spacing: 6) {
                        Text(String(localized: "Passeio Certo")).font(GardenTheme.title)
                        Text(String(localized: "Um passeio de cada vez, com \(session.dogName).")).multilineTextAlignment(.center)
                    }
                    VStack(spacing: 10) {
                        Button(String(localized: "Jogar"), systemImage: "pawprint.fill") { Task { await play() } }
                            .buttonStyle(GardenButtonStyle(prominent: true)).disabled(session.generating)
                        PlayModePicker(selection: Binding(get: { session.preferences.playMode }, set: { session.setPlayMode($0) }))
                        Text(session.preferences.playMode.hasLives ? String(localized: "3 vidas por passeio. Erros custam uma.") : String(localized: "Sem vidas e sem pressa."))
                            .font(.footnote).foregroundStyle(GardenTheme.secondary)
                    }
                    dailyCard(daily, now: timeline.date)
                    cornerSummary
                    if session.generating {
                        ProgressView(String(localized: "Preparando passeio…"))
                        Button(String(localized: "Cancelar")) { session.cancelGeneration() }.buttonStyle(GardenButtonStyle())
                    }
                    if let error = session.storageError {
                        GardenNote(text: error + String(localized: " Abra Jogar para acessar a recuperação."), symbol: "exclamationmark.triangle")
                    }
                }.padding(.horizontal, 20).padding(.bottom, 20).frame(maxWidth: 420).frame(maxWidth: .infinity)
            }.background(GardenTheme.background).foregroundStyle(GardenTheme.ink).tint(GardenTheme.ink)
        }
    }
    /// Jogar always means the normal walk: resume it, or start the next one once it is finished.
    private func play() async {
        if session.activeDailyID != nil { session.continueNormal() }
        if session.attempt.game.won && session.activeDailyID == nil {
            await session.newPuzzle(difficulty: .relaxed)
        }
        if session.activeDailyID == nil && !session.generating { showingHome = false }
    }
    private func dailyCard(_ daily: DailyChallenge, now: Date) -> some View {
        let done = session.completedPuzzleIDs.contains(daily.id)
        let streak = session.dailyStreak(today: now)
        return Button {
            Task {
                await session.openDaily(date: now)
                if session.activeDailyID == daily.id { showingHome = false }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: done ? "checkmark.seal.fill" : "calendar").font(.title)
                    .foregroundStyle(done ? GardenTheme.accent : GardenTheme.terracotta)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Desafio do dia")).font(GardenTheme.heading)
                    Text(done ? String(localized: "Concluído! Novo desafio em \(DailyCountdown.text(from: now))")
                              : String(localized: "Tranquilo · termina em \(DailyCountdown.text(from: now))"))
                        .font(.subheadline).foregroundStyle(GardenTheme.secondary)
                    if streak > 0 {
                        Label(streak == 1 ? String(localized: "1 dia seguido") : String(localized: "\(streak) dias seguidos"), systemImage: "flame.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(GardenTheme.terracotta)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward").foregroundStyle(GardenTheme.secondary)
            }.padding(16)
                .background(GardenTheme.surface, in: RoundedRectangle(cornerRadius: GardenTheme.radius))
                .overlay(RoundedRectangle(cornerRadius: GardenTheme.radius).strokeBorder(GardenTheme.border.opacity(0.6)))
        }.buttonStyle(.plain).disabled(session.generating)
    }
    private var cornerSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Seu cantinho")).font(GardenTheme.heading)
            HStack(spacing: 16) {
                Label(session.completedWalkCount == 1 ? String(localized: "1 passeio") : String(localized: "\(session.completedWalkCount) passeios"), systemImage: "map")
                Label(String(localized: "\(session.totalPaws) patinhas"), systemImage: "pawprint.fill")
            }.font(.subheadline)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(GardenTheme.sage, in: RoundedRectangle(cornerRadius: GardenTheme.radius))
            .accessibilityElement(children: .combine)
    }

    // MARK: Settings

    private var settings: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(String(localized: "Ajustes")).font(GardenTheme.title)
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Nome da sua companhia")).font(GardenTheme.heading)
                    TextField("Margot", text: $nameDraft).textFieldStyle(.roundedBorder)
                        .accessibilityLabel(String(localized: "Nome da cachorrinha"))
                        .submitLabel(.done)
                        .onChange(of: nameDraft) { _, name in session.renameDog(name) }
                    Text(String(localized: "Até 24 caracteres. Em branco, usamos Margot.")).font(.footnote).foregroundStyle(GardenTheme.secondary)
                    if let error = session.storageError { GardenNote(text: error, symbol: "exclamationmark.triangle") }
                }
                Toggle(String(localized: "Sons"), isOn: preferenceBinding(\.soundEnabled))
                Toggle(String(localized: "Feedback tátil"), isOn: preferenceBinding(\.hapticsEnabled))
                Text(String(localized: "Sons suaves e vibrações opcionais. As pistas e mensagens continuam disponíveis com tudo desligado."))
                    .font(.footnote).foregroundStyle(.secondary)
                DisclosureGroup(String(localized: "Como jogar")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "Ligue a cachorrinha à casa por casas vizinhas, sem diagonais nem repetir casas."))
                        Text(String(localized: "As pistas contam as casas ocupadas em cada linha e coluna, incluindo o início e a casa. Uma pista atendida não garante que o caminho inteiro esteja correto."))
                        Text(String(localized: "Arraste, ou toque na casa vizinha à ponta, para desenhar o caminho; volte uma casa para apagar. Toque em outra casa para marcar ×, ou toque e segure em qualquer casa livre; toque de novo para limpar. Dica explica uma dedução sem jogar por você."))
                        Text(String(localized: "No Desafiador você tem 3 vidas. Passar do número de uma pista, pisar num arbusto ou cruzar o caminho custa uma; o erro pisca e a jogada é desfeita. No Tranquilo não há vidas."))
                        Text(String(localized: "Ao chegar em casa, as vidas que sobraram viram patinhas: 3 para um passeio sem erros."))
                    }.fixedSize(horizontal: false, vertical: true).padding(.top, 8)
                }
                Button(session.tutorialStep < TutorialSession.completedStep ? String(localized: "Continuar tutorial") : String(localized: "Repetir tutorial")) {
                    if session.tutorialStep >= TutorialSession.completedStep { session.setTutorialStep(0) }
                    tutorialRequested = true
                }.buttonStyle(GardenButtonStyle())
                Button(String(localized: "Fechar")) { showingLearning = false }.buttonStyle(GardenButtonStyle())
            }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(GardenTheme.background)
        }.background(GardenTheme.background).foregroundStyle(GardenTheme.ink)
            .onAppear { nameDraft = session.dogName }
    }
    private func preferenceBinding(_ keyPath: WritableKeyPath<PlayerPreferences, Bool>) -> Binding<Bool> {
        Binding(get: { session.preferences[keyPath: keyPath] }, set: { value in
            var preferences = session.preferences
            preferences[keyPath: keyPath] = value
            session.setPreferences(preferences)
        })
    }
}

enum DailyCountdown {
    /// "3h 12min" until the next local midnight; minutes only in the last hour.
    static func text(from now: Date) -> String {
        let minutes = max(1, Int(DailyChallenge.nextReset(after: now).timeIntervalSince(now) / 60))
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)min" : "\(minutes)min"
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
                    PuzzleBoard(game: lesson.game, cellSide: side, interactionsEnabled: lesson.target != nil, dogName: lesson.dogName,
                        arrivalProgress: lesson.game.won ? 1 : 0,
                        highlighted: lesson.target.map { Set([$0]) } ?? [],
                        onSelect: { lesson.select($0) },
                        onTap: { cell, _ in lesson.tap(cell) },
                        onStrokeMove: { lesson.drag(to: $0) })
                }.frame(height: side*4)
                if let feedback = lesson.feedback { GardenNote(text: feedback, symbol: "info.circle") }
                if let hint = lesson.hint { GardenNote(text: hint.text, symbol: "lightbulb") }
                if lesson.step == 3 {
                    Button(String(localized: "Desfazer"), systemImage: "arrow.uturn.backward") { lesson.undo() }
                }
                if lesson.step == 4 {
                    Button(String(localized: "Dica"), systemImage: "lightbulb") { lesson.requestHint() }
                }
                if lesson.step == TutorialSession.completedStep {
                    Button(String(localized: "Ir para meu passeio"), systemImage: "pawprint") { onClose() }
                        .buttonStyle(GardenButtonStyle(prominent: true))
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

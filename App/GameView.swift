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
                    onNext: { Task { await session.playNext() } },
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
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { feedbackPlayer.stop(); session.suspend() } else { session.refreshPet() }
        }
        .onDisappear { feedbackPlayer.stop(); session.suspend() }
        .task {
            // Screenshot checks: `simctl launch … -PCOpenWalk YES` skips the home screen; -PCOpenShop YES opens the shop.
            if UserDefaults.standard.bool(forKey: "PCOpenWalk") { showingHome = false }
            session.refreshPet()
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
        if session.activeDailyID != nil { return String(localized: "Desafio do dia") }
        let size = session.attempt.game.puzzle.rows.count
        return (session.attempt.difficulty?.title).map { "\($0) · \(size) × \(size)" } ?? String(localized: "Passeio · \(size) × \(size)")
    }

    // MARK: Home

    /// Margot's room is the home screen.
    private var home: some View {
        PetHomeView(session: session, onPlay: { Task { await play() } },
            onDaily: { now in
                Task {
                    await session.openDaily(date: now)
                    if session.activeDailyID == DailyChallenge(date: now).id { showingHome = false }
                }
            },
            onSettings: { tutorialRequested = false; showingLearning = true },
            onFeedback: { feedbackPlayer.play($0, preferences: session.preferences) })
    }
    /// Passear always means the normal walk: resume it, or start a new one.
    private func play() async {
        await session.play()
        if session.activeDailyID == nil && !session.generating { showingHome = false }
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
                        Text(String(localized: "As pistas contam as casas do caminho em cada linha e coluna, incluindo o início. No Fácil a casinha aparece e também conta; nos outros níveis ela fica escondida e só aparece quando o caminho fecha."))
                        Text(String(localized: "Arraste, ou toque na casa vizinha à ponta, para andar. Cada passo é definitivo: não dá para voltar. Toque e segure numa casa para marcar ×, e de novo para limpar. Dica explica uma dedução sem jogar por você."))
                        Text(String(localized: "Cada fase tem um único caminho certo, e você tem 3 vidas em todos os níveis e no desafio do dia. Tocar numa casa fora do caminho certo, ou andar para ela, custa uma vida."))
                        Text(String(localized: "Ao perder, Tentar de novo recomeça a mesma grade. Ao completar, você escolhe jogar a mesma de novo ou uma nova fase. Outra fase troca por uma grade nova a qualquer momento."))
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

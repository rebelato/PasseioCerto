import SwiftUI

/// One walk on one screen: thin bar, Margot's speech bubble, the largest board that fits, icon toolbar.
struct GameScreen: View {
    @ObservedObject var session: GameSession
    let title: String
    let onHome: () -> Void
    let onSettings: () -> Void
    let onNext: () -> Void
    /// Margot reached the house: the moment for the success haptic.
    let onArrive: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .headline) private var accessibleCell: CGFloat = 48
    @State private var arrivalProgress = 0.0
    @State private var wagging = false
    @State private var enteredHouse = false
    @State private var reset = false
    @State private var recovery = false
    @AccessibilityFocusState private var bubbleFocused: Bool
    private var game: Game { session.attempt.game }
    private var displayedGame: Game { session.displayedGame }
    private var busy: Bool { session.generating || session.stroke != nil || session.hintChecking }

    var body: some View {
        VStack(spacing: 12) {
            GameTopBar(title: title, lives: session.attempt.mode.hasLives ? session.attempt.lives : nil,
                       onHome: onHome, onSettings: onSettings)
            MargotBubble(text: bubbleText, symbol: bubbleSymbol, pose: game.won ? .happy : .idle, accessory: session.preferences.accessory,
                         onClose: session.hint == nil ? nil : { session.dismissHint() })
                .accessibilityFocused($bubbleFocused)
            GeometryReader { space in board(in: space.size) }
            if let error = session.storageError { storageRecovery(error) }
            if session.attempt.defeated {
                Button(String(localized: "Tentar de novo"), systemImage: "arrow.clockwise") { session.restart() }
                    .buttonStyle(GardenButtonStyle(prominent: true))
            } else {
                GameToolbar(canUndo: game.canUndo, canPlay: session.canInteract && !busy,
                            onUndo: session.undo, onHint: { Task { await session.requestHint() } }, onRestart: { reset = true })
            }
        }
        .padding(.horizontal, GardenTheme.spacing).padding(.bottom, 8)
        .frame(maxWidth: 560).frame(maxWidth: .infinity)
        .background(GardenTheme.background).foregroundStyle(GardenTheme.ink).tint(GardenTheme.accent)
        .confirmationDialog(String(localized: "Reiniciar esta fase?"), isPresented: $reset, titleVisibility: .visible) {
            Button(String(localized: "Reiniciar"), role: .destructive) { session.restart() }
        }
        .confirmationDialog(String(localized: "Salvar esta partida no lugar da anterior? O arquivo anterior será guardado separadamente."), isPresented: $recovery, titleVisibility: .visible) {
            Button(String(localized: "Preservar original e salvar esta partida")) { session.preserveOriginalAndSaveCurrent() }
        }
        .sheet(isPresented: .constant(game.won && !session.celebrating)) {
            VictorySheet(dogName: session.dogName, paws: session.attempt.paws,
                         best: session.bestPaws[game.puzzle.puzzleID] ?? session.attempt.paws,
                         isDaily: session.activeDailyID != nil, generating: session.generating,
                         onNext: onNext, onReplay: { session.restart() }, onHome: onHome)
        }
        .task(id: session.celebrating) { await celebrate() }
        .onChange(of: game.won) { _, won in if !won { enteredHouse = false; wagging = false } }
        .onChange(of: session.hint) { _, hint in bubbleFocused = hint != nil }
    }

    private var bubbleText: String {
        if let hint = session.hint { return hint.text }
        if session.hintChecking { return String(localized: "Pensando numa dica…") }
        if session.generating { return String(localized: "Preparando o próximo passeio…") }
        if session.celebrating && !game.puzzle.trees.isEmpty {
            return String(localized: "\(session.dogName) fez uma paradinha estratégica na árvore… pronto, agora casa!")
        }
        if game.won { return String(localized: "Chegamos em casa!") }
        if session.attempt.defeated { return String(localized: "As vidas acabaram. Vamos tentar de novo?") }
        if let message = session.message { return message }
        // First walk of a new place: Margot introduces its rule.
        if let level = session.attempt.level, level.level == 0, let rule = level.world.newRule, game.path.count == 1, game.marks.isEmpty {
            return String(localized: "Novidade, \(rule.title.lowercased())! \(rule.explanation)")
        }
        return String(localized: "Leve \(session.dogName) até a casinha")
    }
    private var bubbleSymbol: String? {
        if let hint = session.hint { return hint.kind == .conflict ? "exclamationmark.triangle" : "lightbulb" }
        return session.displayedViolation == nil ? nil : "exclamationmark.circle"
    }

    @ViewBuilder private func board(in size: CGSize) -> some View {
        let columns = CGFloat(game.columns.count + 1), rows = CGFloat(game.rows.count + 1)
        let fitted = floor(min(size.width / columns, size.height / rows))
        let content = PuzzleBoard(game: displayedGame, cellSide: textSize.isAccessibilitySize ? max(fitted, accessibleCell) : fitted,
            interactionsEnabled: session.canInteract,
            onSelectMode: { cell, marking in Task { await session.select(cell, marking: marking) } }, dogName: session.dogName,
            accessory: session.preferences.accessory,
            arrivalProgress: game.won ? (session.celebrating ? arrivalProgress : 1) : 0,
            walking: session.celebrating && !reduceMotion && !wagging, wagging: wagging, enteredHouse: enteredHouse,
            highlighted: session.hint?.cells ?? [], highlightedRow: session.hint?.row,
            highlightedColumn: session.hint?.column, violation: session.displayedViolation,
            onSelect: { cell in Task { await session.select(cell, marking: false) } },
            onTap: { cell in Task { await session.select(cell, marking: true) } },
            onStrokeStart: { session.begin(at: $0, marking: false) },
            onStrokeMove: { session.move(to: $0) },
            onStrokeEnd: { cancelled in
                if cancelled { session.cancel() } else { Task { await session.finish() } }
            })
            .allowsHitTesting(session.canInteract)
            .accessibilityHidden(session.attempt.defeated)
            .overlay { if session.generating { ProgressView().controlSize(.large) } }
        if textSize.isAccessibilitySize && fitted < accessibleCell {
            ScrollView([.horizontal, .vertical]) { content }
        } else {
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private func storageRecovery(_ error: String) -> some View {
        VStack(spacing: 8) {
            GardenNote(text: error, symbol: "exclamationmark.triangle")
            if session.backupAvailable {
                Button(String(localized: "Recuperar cópia anterior")) { session.recoverBackup() }
            }
            Button(String(localized: "Tentar salvar novamente")) { session.retrySave() }
            Button(String(localized: "Salvar esta partida preservando o arquivo original")) { recovery = true }
        }.buttonStyle(GardenButtonStyle())
    }

    /// Walk the route, wag, hop into the house; then the result sheet appears.
    private func celebrate() async {
        guard session.celebrating else { arrivalProgress = 0; return }
        if reduceMotion { onArrive(); session.finishCelebration(); return }
        arrivalProgress = 0; wagging = false; enteredHouse = false
        // Give the start position a render pass before beginning the route.
        do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
        let walk = min(3, max(1.2, Double(game.path.count) * 0.22))
        withAnimation(.linear(duration: walk)) { arrivalProgress = 1 }
        do { try await Task.sleep(for: .seconds(walk)) } catch { return }
        onArrive()
        wagging = true
        do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
        wagging = false
        withAnimation(.easeIn(duration: 0.35)) { enteredHouse = true }
        do { try await Task.sleep(for: .milliseconds(450)) } catch { return }
        session.finishCelebration()
    }
}

struct GameTopBar: View {
    let title: String
    let lives: Int?
    let onHome: () -> Void
    let onSettings: () -> Void
    var body: some View {
        HStack {
            Button(action: onHome) { Image(systemName: "chevron.backward").font(.title3.weight(.semibold)) }
                .frame(width: GardenTheme.minTarget, height: GardenTheme.minTarget)
                .accessibilityLabel(String(localized: "Início"))
            Spacer(minLength: 4)
            VStack(spacing: 2) {
                Text(title).font(GardenTheme.heading).lineLimit(1).minimumScaleFactor(0.8)
                if let lives {
                    HStack(spacing: 4) {
                        ForEach(0..<GameAttempt.maxLives, id: \.self) { index in
                            Image(systemName: index < lives ? "heart.fill" : "heart")
                                .foregroundStyle(GardenTheme.terracotta).font(.caption)
                        }
                    }.accessibilityElement(children: .ignore)
                        .accessibilityLabel(lives == 1 ? String(localized: "1 vida restante de 3") : String(localized: "\(lives) vidas restantes de 3"))
                }
            }
            Spacer(minLength: 4)
            Button(action: onSettings) { Image(systemName: "gearshape").font(.title3) }
                .frame(width: GardenTheme.minTarget, height: GardenTheme.minTarget)
                .accessibilityLabel(String(localized: "Ajustes"))
        }.foregroundStyle(GardenTheme.ink)
    }
}

/// Margot speaks only when there is something to say; otherwise she states the goal.
struct MargotBubble: View {
    let text: String
    var symbol: String?
    var pose: MargotPose = .idle
    var accessory: Accessory?
    var onClose: (() -> Void)?
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Puppy(pose: pose, accessory: accessory).frame(width: 40, height: 40)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let symbol { Image(systemName: symbol).foregroundStyle(GardenTheme.accent) }
                Text(text).font(GardenTheme.body).lineLimit(5).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
            if let onClose {
                Button(action: onClose) { Image(systemName: "xmark.circle.fill").font(.title3) }
                    .foregroundStyle(GardenTheme.secondary)
                    .frame(width: GardenTheme.minTarget, height: GardenTheme.minTarget)
                    .accessibilityLabel(String(localized: "Fechar dica"))
            }
        }.padding(.horizontal, 12).padding(.vertical, 8)
            .background(GardenTheme.sage, in: RoundedRectangle(cornerRadius: GardenTheme.radius))
            .accessibilityElement(children: .contain)
            .animation(.easeOut(duration: 0.2), value: text)
    }
}

struct GameToolbar: View {
    let canUndo: Bool
    let canPlay: Bool
    let onUndo: () -> Void
    let onHint: () -> Void
    let onRestart: () -> Void
    var body: some View {
        HStack(spacing: 4) {
            Button(String(localized: "Desfazer"), systemImage: "arrow.uturn.backward", action: onUndo).disabled(!canPlay || !canUndo)
            Button(String(localized: "Dica"), systemImage: "lightbulb", action: onHint).disabled(!canPlay)
            Button(String(localized: "Reiniciar"), systemImage: "arrow.clockwise", action: onRestart).disabled(!canPlay)
        }.buttonStyle(GardenIconButtonStyle())
            .padding(4).background(GardenTheme.surface, in: RoundedRectangle(cornerRadius: GardenTheme.radius))
            .overlay(RoundedRectangle(cornerRadius: GardenTheme.radius).strokeBorder(GardenTheme.border.opacity(0.5)))
    }
}

/// The one place the walk's result is told: paws earned and what to do next.
struct VictorySheet: View {
    let dogName: String
    let paws: Int
    let best: Int
    let isDaily: Bool
    let generating: Bool
    let onNext: () -> Void
    let onReplay: () -> Void
    let onHome: () -> Void
    @AccessibilityFocusState private var titleFocused: Bool
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Puppy(pose: .happy).frame(width: 72, height: 72)
                Text(String(localized: "Passeio concluído!")).font(.title2.weight(.bold)).fontDesign(.serif)
                    .accessibilityFocused($titleFocused)
                PawScore(paws: paws)
                Text(paws == GameAttempt.maxLives ? String(localized: "\(dogName) adorou: passeio perfeito!")
                     : best > paws ? String(localized: "Seu recorde aqui é de \(best) patinhas.")
                     : String(localized: "Sem erros, o passeio vale 3 patinhas."))
                    .font(.subheadline).foregroundStyle(GardenTheme.secondary).multilineTextAlignment(.center)
                if isDaily {
                    Button(String(localized: "Voltar ao início"), systemImage: "house", action: onHome)
                        .buttonStyle(GardenButtonStyle(prominent: true))
                } else {
                    Button(String(localized: "Próximo passeio"), systemImage: "arrow.forward", action: onNext)
                        .buttonStyle(GardenButtonStyle(prominent: true)).disabled(generating)
                }
                Button(String(localized: "Jogar de novo"), systemImage: "arrow.clockwise", action: onReplay)
                    .buttonStyle(GardenButtonStyle()).disabled(generating)
                if !isDaily {
                    Button(String(localized: "Início"), action: onHome).font(GardenTheme.heading).padding(.top, 2)
                }
            }.padding(24).frame(maxWidth: .infinity)
        }
        .foregroundStyle(GardenTheme.ink).tint(GardenTheme.ink)
        .background(GardenTheme.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
        .onAppear { titleFocused = true }
    }
}

import SwiftUI

struct GameView: View {
    @StateObject private var session = GameSession(saveURL: URL.applicationSupportDirectory.appending(path: "PasseioCerto/attempt.json"))
    private var game: Game { session.attempt.game }
    @Environment(\.scenePhase) private var scenePhase
    private var marking: Bool { session.preferences.marking }
    private var markingBinding: Binding<Bool> {
        Binding(get: { session.preferences.marking }, set: { session.setMarking($0) })
    }
    @AccessibilityFocusState private var hintFocused: Bool
    @State private var recovery = false
    @State private var reset = false
    @State private var newPuzzle = false
    @State private var difficulty = PuzzleDifficulty.relaxed
    @ScaledMetric(relativeTo: .headline) private var cellMinimum: CGFloat = 48
    private var displayedGame: Game { session.displayedGame }
    private let green = GardenTheme.accent
    var body: some View {
        GeometryReader { screen in
        let side = max((min(screen.size.width, 420) - 32) / CGFloat(game.columns.count + 1), cellMinimum)
        ScrollView {
            VStack(spacing: GardenTheme.spacing) {
                Text("Passeio Certo").font(GardenTheme.title).foregroundStyle(GardenTheme.ink)
                Text("Praça das Flores · 5 × 5").font(.subheadline)
                HStack(spacing: 10) {
                    ForEach(0..<3) { index in
                        Image(systemName: index < session.attempt.lives ? "heart.fill" : "heart")
                            .foregroundStyle(GardenTheme.terracotta).font(.title3)
                    }
                    Text("\(session.attempt.lives) de 3 vidas").font(.subheadline)
                }.accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(session.attempt.lives) vidas restantes de 3")
                HStack(spacing: 12) {
                    Puppy().frame(width: 52, height: 52)
                    Text(displayedGame.won ? "Chegamos em casa!" : "Leve a Margot até a casinha")
                        .font(GardenTheme.heading).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(GardenTheme.sage, in: RoundedRectangle(cornerRadius: GardenTheme.radius))
                ScrollView(.horizontal) {
                    PuzzleBoard(game: displayedGame, cellSide: side,
                        highlighted: session.hint?.cells ?? [], highlightedRow: session.hint?.row,
                        highlightedColumn: session.hint?.column, onSelect: select,
                        onStrokeStart: { session.begin(at: $0, marking: marking) },
                        onStrokeMove: { session.move(to: $0) },
                        onStrokeEnd: finishStroke)
                        .allowsHitTesting(session.canInteract)
                        .accessibilityHidden(session.attempt.defeated)
                }.frame(height: CGFloat(game.rows.count + 1) * side)
                GardenNote(text: session.message, symbol: game.won ? "checkmark.circle" : "info.circle")
                if let hint = session.hint {
                    VStack(alignment: .leading, spacing: 8) {
                        GardenNote(text: hint.text, symbol: hint.kind == .conflict ? "exclamationmark.triangle" : "lightbulb")
                            .accessibilityFocused($hintFocused)
                        Button("Fechar dica", systemImage: "xmark.circle") { session.dismissHint() }
                            .buttonStyle(GardenButtonStyle())
                    }
                }
                if session.generating {
                    ProgressView("Preparando novo passeio…")
                    Button("Cancelar geração", systemImage: "xmark.circle") { session.cancelGeneration() }
                        .buttonStyle(GardenButtonStyle())
                }
                if session.hintChecking { ProgressView("Preparando dica…") }
                if session.checking { ProgressView("Verificando jogada…") }
                if let error = session.storageError {
                    GardenNote(text: error, symbol: "exclamationmark.triangle")
                    VStack {
                        if session.backupAvailable {
                            Button("Recuperar cópia anterior") { session.recoverBackup() }
                        }
                        Button("Tentar salvar novamente") { session.retrySave() }
                        Button("Salvar esta partida preservando o arquivo original") { recovery = true }
                    }.buttonStyle(GardenButtonStyle())
                }
                if session.attempt.defeated {
                    Button("Tentar novamente", systemImage: "arrow.clockwise") { session.restart() }
                        .buttonStyle(GardenButtonStyle())
                }
                GardenTools(marking: markingBinding).disabled(session.generating || session.stroke != nil || session.checking || session.hintChecking || session.attempt.defeated)
                HStack {
                    Button("Desfazer", systemImage: "arrow.uturn.backward") { session.undo() }.disabled(!game.canUndo)
                    Button("Dica", systemImage: "lightbulb") {
                        Task { await session.requestHint() }
                    }.disabled(!session.canInteract)
                }.buttonStyle(GardenButtonStyle()).disabled(session.generating || session.stroke != nil || session.checking || session.hintChecking || session.attempt.defeated)
                HStack {
                    Button("Reiniciar", systemImage: "arrow.clockwise") { reset = true }
                }.buttonStyle(GardenButtonStyle()).disabled(session.generating || session.stroke != nil || session.checking || session.hintChecking || session.attempt.defeated)
                Picker("Dificuldade da próxima fase", selection: $difficulty) {
                    ForEach(PuzzleDifficulty.allCases, id: \.self) { level in
                        Text(level.title).tag(level)
                    }
                }.pickerStyle(.segmented).disabled(session.generating)
                Button("Nova fase", systemImage: "sparkles") { newPuzzle = true }
                    .buttonStyle(GardenButtonStyle())
                    .disabled(session.generating || session.checking || session.hintChecking || session.stroke != nil)
                Text("Arraste ou toque nas casas vizinhas. Volte uma casa para apagar. Para rolar, arraste pelas pistas ou fora da grade.").font(.footnote).foregroundStyle(.secondary)
            }.padding(GardenTheme.spacing).frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
        }.background(GardenTheme.background).foregroundStyle(GardenTheme.ink).tint(green)
            .confirmationDialog("Reiniciar esta fase?", isPresented: $reset, titleVisibility: .visible) {
                Button("Reiniciar", role: .destructive) { session.restart() }
            }
        }
        .confirmationDialog("Começar uma nova fase? A tentativa atual será substituída quando a nova fase estiver pronta.", isPresented: $newPuzzle, titleVisibility: .visible) {
            Button("Gerar fase · \(difficulty.title)") {
                Task { await session.newPuzzle(difficulty: difficulty) }
            }
        }
        .confirmationDialog("Salvar esta partida no lugar da anterior? O arquivo anterior será guardado separadamente.", isPresented: $recovery, titleVisibility: .visible) {
            Button("Preservar original e salvar esta partida") { session.preserveOriginalAndSaveCurrent() }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { session.suspend() } }
        .onChange(of: session.hint) { _, value in hintFocused = value != nil }
        .onChange(of: marking) { _, _ in finishStroke(true) }
        .onDisappear { session.suspend() }
    }
    private func finishStroke(_ cancelled: Bool) {
        if cancelled { session.cancel() }
        else { Task { await session.finish() } }
    }
    private func select(_ cell: Cell) {
        Task { await session.select(cell, marking: marking) }
    }
}

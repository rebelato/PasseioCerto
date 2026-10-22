import SwiftUI

struct GameView: View {
    @StateObject private var session = GameSession(saveURL: URL.applicationSupportDirectory.appending(path: "PasseioCerto/attempt.json"))
    private var game: Game { session.attempt.game }
    @Environment(\.scenePhase) private var scenePhase
    @State private var marking = false
    @State private var reset = false
    @ScaledMetric(relativeTo: .headline) private var cellMinimum: CGFloat = 48
    private var displayedGame: Game { session.displayedGame }
    private let green = GardenTheme.accent
    var body: some View {
        GeometryReader { screen in
        let side = max((min(screen.size.width, 420) - 32) / CGFloat(game.columns.count + 1), cellMinimum)
        ScrollView {
            VStack(spacing: GardenTheme.spacing) {
                Text("Passeio Certo").font(GardenTheme.title).foregroundStyle(GardenTheme.ink)
                Text("Praça das Flores · Fase 1").font(.subheadline)
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
                    PuzzleBoard(game: displayedGame, cellSide: side, onSelect: select,
                        onStrokeStart: { session.begin(at: $0, marking: marking) },
                        onStrokeMove: { session.move(to: $0) },
                        onStrokeEnd: finishStroke)
                        .allowsHitTesting(session.canInteract)
                        .accessibilityHidden(session.attempt.defeated)
                }.frame(height: CGFloat(game.rows.count + 1) * side)
                GardenNote(text: session.message, symbol: game.won ? "checkmark.circle" : "info.circle")
                if session.checking { ProgressView("Verificando jogada…") }
                if let error = session.storageError { GardenNote(text: error, symbol: "exclamationmark.triangle") }
                if session.attempt.defeated {
                    Button("Tentar novamente", systemImage: "arrow.clockwise") { session.restart() }
                        .buttonStyle(GardenButtonStyle())
                }
                GardenTools(marking: $marking).disabled(session.stroke != nil || session.checking || session.attempt.defeated)
                HStack {
                    Button("Desfazer", systemImage: "arrow.uturn.backward") { session.undo() }.disabled(!game.canUndo)
                    Spacer()
                    Button("Reiniciar", systemImage: "arrow.clockwise") { reset = true }
                }.buttonStyle(GardenButtonStyle()).disabled(session.stroke != nil || session.checking || session.attempt.defeated)
                Text("Arraste ou toque nas casas vizinhas. Volte uma casa para apagar. Para rolar, arraste pelas pistas ou fora da grade.").font(.footnote).foregroundStyle(.secondary)
            }.padding(GardenTheme.spacing).frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
        }.background(GardenTheme.background).foregroundStyle(GardenTheme.ink).tint(green)
            .confirmationDialog("Reiniciar esta fase?", isPresented: $reset, titleVisibility: .visible) {
                Button("Reiniciar", role: .destructive) { session.restart() }
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { finishStroke(true) } }
        .onChange(of: marking) { _, _ in finishStroke(true) }
        .onDisappear { finishStroke(true) }
    }
    private func finishStroke(_ cancelled: Bool) {
        if cancelled { session.cancel() }
        else { Task { await session.finish() } }
    }
    private func select(_ cell: Cell) {
        Task { await session.select(cell, marking: marking) }
    }
}

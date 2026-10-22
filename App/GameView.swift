import SwiftUI

struct GameView: View {
    @State private var game = Game()
    @State private var marking = false
    @State private var reset = false
    @State private var message = "Os números indicam quantas casas o caminho ocupa."
    @ScaledMetric(relativeTo: .headline) private var cellMinimum: CGFloat = 48
    private let green = GardenTheme.accent
    var body: some View {
        GeometryReader { screen in
        let side = max((min(screen.size.width, 420) - 32) / CGFloat(game.columns.count + 1), cellMinimum)
        ScrollView {
            VStack(spacing: GardenTheme.spacing) {
                Text("Passeio Certo").font(GardenTheme.title).foregroundStyle(GardenTheme.ink)
                Text("Praça das Flores · Fase 1").font(.subheadline)
                HStack(spacing: 12) {
                    Puppy().frame(width: 52, height: 52)
                    Text(game.won ? "Chegamos em casa!" : "Leve a Margot até a casinha")
                        .font(GardenTheme.heading).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(GardenTheme.sage, in: RoundedRectangle(cornerRadius: GardenTheme.radius))
                ScrollView(.horizontal) {
                    PuzzleBoard(game: game, cellSide: side, onSelect: select)
                }.frame(height: CGFloat(game.rows.count + 1) * side)
                GardenNote(text: message, symbol: game.won ? "checkmark.circle" : "info.circle")
                GardenTools(marking: $marking)
                HStack {
                    Button("Desfazer", systemImage: "arrow.uturn.backward") { game.undo(); message = "Última ação desfeita. Continue seguindo as pistas." }.disabled(!game.canUndo)
                    Spacer()
                    Button("Reiniciar", systemImage: "arrow.clockwise") { reset = true }
                }.buttonStyle(GardenButtonStyle())
                Text("Toque nas casas vizinhas para desenhar. Volte uma casa para apagar o último trecho.").font(.footnote).foregroundStyle(.secondary)
            }.padding(GardenTheme.spacing).frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
        }.background(GardenTheme.background).foregroundStyle(GardenTheme.ink).tint(green)
            .confirmationDialog("Reiniciar esta fase?", isPresented: $reset, titleVisibility: .visible) {
                Button("Reiniciar", role: .destructive) { game = Game(); message = "Os números indicam quantas casas o caminho ocupa." }
            }
        }
    }
    private func select(_ cell: Cell) {
        if !game.play(cell, marking: marking) {
            message = "Use uma casa vizinha livre, sem ultrapassar as pistas."
        } else {
            switch game.status {
            case .complete: message = "Margot chegou! Todas as pistas foram atendidas."
            case .contradiction(.arrivedBeforeClues): message = "Chegou à casa, mas ainda faltam casas nas pistas. Volte um trecho ou use Desfazer."
            default: message = "Continue seguindo as pistas das linhas e colunas."
            }
        }
    }
}

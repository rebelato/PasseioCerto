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
        let boardWidth = max(min(screen.size.width, 420) - 32, cellMinimum * 6)
        ScrollView {
            VStack(spacing: GardenTheme.spacing) {
                Text("Passeio Certo").font(GardenTheme.title).foregroundStyle(GardenTheme.ink)
                Text("Praça das Flores · Fase 1").font(.subheadline)
                HStack(spacing: 12) {
                    Puppy().frame(width: 52, height: 52)
                    Text(game.won ? "Chegamos em casa!" : "Leve sua companheira até a casinha")
                        .font(GardenTheme.heading).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(GardenTheme.sage, in: RoundedRectangle(cornerRadius: GardenTheme.radius))
                ScrollView(.horizontal) {
                    board.frame(width: boardWidth, height: boardWidth)
                }.frame(height: boardWidth)
                GardenNote(text: message, symbol: game.won ? "checkmark.circle" : "info.circle")
                GardenTools(marking: $marking)
                HStack {
                    Button("Desfazer", systemImage: "arrow.uturn.backward") { game.undo() }.disabled(!game.canUndo)
                    Spacer()
                    Button("Reiniciar", systemImage: "arrow.clockwise") { reset = true }
                }.buttonStyle(GardenButtonStyle())
                Text("Toque nas casas vizinhas para desenhar. Volte uma casa para apagar o último trecho.").font(.footnote).foregroundStyle(.secondary)
            }.padding(GardenTheme.spacing).frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
        }.background(GardenTheme.background).foregroundStyle(GardenTheme.ink).tint(green)
            .confirmationDialog("Reiniciar esta fase?", isPresented: $reset, titleVisibility: .visible) {
                Button("Reiniciar", role: .destructive) { game = Game() }
            }
        }
    }
    private var board: some View {
        GeometryReader { geo in
            let side = geo.size.width / 6
            ZStack(alignment: .topLeading) {
                ForEach(0..<5) { i in
                    GardenClue(target: game.columns[i], count: game.columnCounts[i], label: "Coluna \(i+1)").padding(2).frame(width: side, height: side).offset(x: Double(i+1)*side)
                    GardenClue(target: game.rows[i], count: game.rowCounts[i], label: "Linha \(i+1)").padding(2).frame(width: side, height: side).offset(y: Double(i+1)*side)
                }
                ForEach(0..<25) { i in
                    let cell = Cell(i/5, i%5)
                    Button {
                        if !game.play(cell, marking: marking) { message = "Use uma casa vizinha livre, sem ultrapassar as pistas." }
                        else {
                            switch game.status {
                            case .complete: message = "Todas as pistas foram atendidas. Muito bem!"
                            case .contradiction(.arrivedBeforeClues): message = "Chegou à casa, mas ainda faltam casas nas pistas. Volte um trecho ou use Desfazer."
                            default: message = "Continue seguindo as pistas das linhas e colunas."
                            }
                        }
                    } label: {
                        GardenCell(occupied: game.path.contains(cell), excluded: game.marks.contains(cell), obstacle: game.puzzle.obstacles.contains(cell))
                    }.buttonStyle(.plain).frame(width: side-4, height: side-4)
                        .offset(x: Double(cell.col+1)*side+2, y: Double(cell.row+1)*side+2)
                        .accessibilityLabel("Linha \(cell.row+1), coluna \(cell.col+1)" )
                        .accessibilityValue(cell == game.start ? "Cachorrinha" : cell == game.goal ? "Casa" : game.path.contains(cell) ? "Caminho" : game.marks.contains(cell) ? "Marcada com xis" : "Livre")
                }
                Path { p in
                    for (i, c) in game.path.enumerated() {
                        let point = CGPoint(x: (Double(c.col)+1.5)*side, y: (Double(c.row)+1.5)*side)
                        if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
                    }
                }.stroke(green, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)).allowsHitTesting(false)
                ForEach([game.start, game.goal], id: \.self) { cell in
                    Group {
                        if cell == game.start { Puppy().padding(5) }
                        else { Image(systemName: "house.fill").font(.title2).foregroundStyle(GardenTheme.terracotta) }
                    }.frame(width: side-4, height: side-4)
                        .offset(x: Double(cell.col+1)*side+2, y: Double(cell.row+1)*side+2)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
        }
    }
}

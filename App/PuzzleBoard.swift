import SwiftUI

/// Draws the actual model. Dimensions, endpoints and clues are never hardcoded.
struct PuzzleBoard: View {
    let game: Game
    let cellSide: CGFloat
    var highlighted: Set<Cell> = []
    var highlightedRow: Int?
    var highlightedColumn: Int?
    var onSelect: (Cell) -> Void = { _ in }
    var onStrokeStart: (Cell) -> Void = { _ in }
    var onStrokeMove: (Cell?) -> Void = { _ in }
    var onStrokeEnd: (Bool) -> Void = { _ in }
    @GestureState private var touching = false
    @State private var strokeStarted = false
    private var width: CGFloat { CGFloat(game.columns.count + 1) * cellSide }
    private var height: CGFloat { CGFloat(game.rows.count + 1) * cellSide }
    private var cells: [Cell] {
        game.rows.indices.flatMap { r in game.columns.indices.map { Cell(r,$0) } }
    }
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(game.columns.indices, id: \.self) { col in
                GardenClue(target: game.columns[col], count: game.columnCounts[col], label: "Coluna \(col+1)")
                    .overlay { if highlightedColumn == col { RoundedRectangle(cornerRadius: GardenTheme.cellRadius).strokeBorder(GardenTheme.accent, lineWidth: 3) } }
                    .padding(2).frame(width: cellSide, height: cellSide)
                    .offset(x: CGFloat(col+1)*cellSide)
            }
            ForEach(game.rows.indices, id: \.self) { row in
                GardenClue(target: game.rows[row], count: game.rowCounts[row], label: "Linha \(row+1)")
                    .overlay { if highlightedRow == row { RoundedRectangle(cornerRadius: GardenTheme.cellRadius).strokeBorder(GardenTheme.accent, lineWidth: 3) } }
                    .padding(2).frame(width: cellSide, height: cellSide)
                    .offset(y: CGFloat(row+1)*cellSide)
            }
            ForEach(cells, id: \.self) { cell in
                GardenCell(occupied: game.path.contains(cell), excluded: game.marks.contains(cell),
                               obstacle: game.puzzle.obstacles.contains(cell), highlighted: highlighted.contains(cell))
                        .padding(2).contentShape(Rectangle())
                    .frame(width: cellSide, height: cellSide)
                    .highPriorityGesture(stroke(start: cell))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { onSelect(cell) }
                    .offset(x: CGFloat(cell.col+1)*cellSide, y: CGFloat(cell.row+1)*cellSide)
                    .accessibilityIdentifier("cell-\(cell.row)-\(cell.col)")
                    .accessibilityLabel("Linha \(cell.row+1), coluna \(cell.col+1)")
                    .accessibilityValue(accessibleState(cell))
                    .accessibilityHint(game.puzzle.obstacles.contains(cell) ? "Não pode fazer parte do caminho" : "Ativa a ferramenta selecionada nesta casa")
            }
            Path { p in
                for (index, cell) in game.path.enumerated() {
                    let center = CGPoint(x: (CGFloat(cell.col)+1.5)*cellSide, y: (CGFloat(cell.row)+1.5)*cellSide)
                    if index == 0 { p.move(to: center) } else { p.addLine(to: center) }
                }
            }.stroke(GardenTheme.accent, style: StrokeStyle(lineWidth: max(5, cellSide*0.12), lineCap: .round, lineJoin: .round))
                .frame(width: width, height: height).allowsHitTesting(false).accessibilityHidden(true)
            ForEach([game.start, game.goal], id: \.self) { cell in
                Group {
                    if cell == game.start { Puppy().padding(5) }
                    else { Image(systemName: "house.fill").font(.title2).foregroundStyle(GardenTheme.terracotta) }
                }.frame(width: cellSide-4, height: cellSide-4)
                    .offset(x: CGFloat(cell.col+1)*cellSide+2, y: CGFloat(cell.row+1)*cellSide+2)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }.frame(width: width, height: height)
            .coordinateSpace(name: "puzzle-board")
            .onChange(of: touching) { _, active in
                if !active {
                    // onEnded commits first; recognizer cancellation has no onEnded.
                    DispatchQueue.main.async {
                        if !touching && strokeStarted { strokeStarted = false; onStrokeEnd(true) }
                    }
                }
            }
            .onDisappear { if strokeStarted { strokeStarted = false; onStrokeEnd(true) } }
    }
    private func stroke(start: Cell) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("puzzle-board"))
            .updating($touching) { _, active, _ in active = true }
            .onChanged { value in
                if !strokeStarted { strokeStarted = true; onStrokeStart(start) }
                onStrokeMove(BoardHitTest.cell(x: value.location.x, y: value.location.y,
                    side: cellSide, rows: game.rows.count, columns: game.columns.count))
            }
            .onEnded { _ in
                if strokeStarted { strokeStarted = false; onStrokeEnd(false) }
            }
    }
    private func accessibleState(_ cell: Cell) -> String {
        let state: String
        if cell == game.start { state = "Margot, início do caminho" }
        else if cell == game.goal { state = game.path.last == cell ? "Casinha, caminho conectado" : "Casinha, ainda não conectada" }
        else if game.puzzle.obstacles.contains(cell) { state = "Obstáculo" }
        else if game.path.contains(cell) { state = "Caminho" }
        else if game.marks.contains(cell) { state = "Marcada com xis" }
        else { state = "Livre" }
        return highlighted.contains(cell) ? state + ", destacada pela dica" : state
    }
}

/// Fixed inputs for visual checks; no network, generation or reference-solution lookup at runtime.
enum BoardSamples {
    static var partial: Game {
        var game = Game()
        for cell in PuzzleFixtures.approved.witnessRoutes[0].dropFirst().prefix(4) { game.play(cell) }
        for cell in [Cell(0,3),Cell(0,4),Cell(3,2)] { game.play(cell, marking: true) }
        return game
    }
    static var touching: Game {
        var game = Game(puzzle: try! PuzzleFixtures.ambiguous.makePuzzle())
        for cell in PuzzleFixtures.ambiguous.witnessRoutes[0].dropFirst() { game.play(cell) }
        return game
    }
}
struct BoardPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            PuzzleBoard(game: BoardSamples.partial, cellSide: 48).previewDisplayName("Parcial · 288 pt")
            PuzzleBoard(game: BoardSamples.touching, cellSide: 60).previewDisplayName("Arestas explícitas")
            PuzzleBoard(game: Game(puzzle: try! PuzzleFixtures.perimeter.makePuzzle()), cellSide: 48).previewDisplayName("Obstáculo")
            PuzzleBoard(game: BoardSamples.partial, cellSide: 72, highlighted: [Cell(2,3)])
                .environment(\.dynamicTypeSize, .accessibility2).previewDisplayName("Texto ampliado")
        }.padding(12).background(GardenTheme.background)
    }
}

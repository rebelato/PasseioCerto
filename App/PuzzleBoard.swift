import SwiftUI

/// Draws the actual model. Dimensions, endpoints and clues are never hardcoded.
struct PuzzleBoard: View {
    let game: Game
    let cellSide: CGFloat
    var marking = false
    var interactionsEnabled = true
    var onSelectMode: ((Cell, Bool) -> Void)?
    var dogName = "Margot"
    var arrivalProgress: Double = 0
    var walking = false
    /// Victory beats after the walk: a tail wag, then a hop into the house.
    var wagging = false
    var enteredHouse = false
    var highlighted: Set<Cell> = []
    var highlightedRow: Int?
    var highlightedColumn: Int?
    /// A visible mistake: the cell and clue blink in the error color before the move is undone.
    var violation: StrokeViolation?
    var onSelect: (Cell) -> Void = { _ in }
    /// A touch that never leaves its cell, and whether it was held (long press).
    var onTap: (Cell, Bool) -> Void = { _, _ in }
    var onStrokeStart: (Cell) -> Void = { _ in }
    var onStrokeMove: (Cell?) -> Void = { _ in }
    var onStrokeEnd: (Bool) -> Void = { _ in }
    @GestureState private var touching = false
    @State private var strokeStarted = false
    @State private var touchStart: Date?
    private var width: CGFloat { CGFloat(game.columns.count + 1) * cellSide }
    private var height: CGFloat { CGFloat(game.rows.count + 1) * cellSide }
    private var cells: [Cell] {
        game.rows.indices.flatMap { r in game.columns.indices.map { Cell(r,$0) } }
    }
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(game.columns.indices, id: \.self) { col in
                GardenClue(target: game.columns[col], count: game.columnCounts[col], label: String(localized: "Coluna \(col+1)"), blocked: violation?.column == col)
                    .overlay { if highlightedColumn == col { RoundedRectangle(cornerRadius: GardenTheme.cellRadius).strokeBorder(GardenTheme.accent, lineWidth: 3) } }
                    .padding(2).frame(width: cellSide, height: cellSide)
                    .offset(x: CGFloat(col+1)*cellSide)
                    .accessibilitySortPriority(Double(1000-col))
            }
            ForEach(game.rows.indices, id: \.self) { row in
                GardenClue(target: game.rows[row], count: game.rowCounts[row], label: String(localized: "Linha \(row+1)"), blocked: violation?.row == row)
                    .overlay { if highlightedRow == row { RoundedRectangle(cornerRadius: GardenTheme.cellRadius).strokeBorder(GardenTheme.accent, lineWidth: 3) } }
                    .padding(2).frame(width: cellSide, height: cellSide)
                    .offset(y: CGFloat(row+1)*cellSide)
                    .accessibilitySortPriority(Double((game.rows.count-row)*(game.columns.count+1)+1))
            }
            ForEach(cells, id: \.self) { cell in
                GardenCell(occupied: game.path.contains(cell), excluded: game.marks.contains(cell),
                               obstacle: game.puzzle.obstacles.contains(cell), highlighted: highlighted.contains(cell),
                               blocked: violation?.cell == cell)
                        .padding(2).contentShape(Rectangle())
                    .frame(width: cellSide, height: cellSide)
                    .highPriorityGesture(stroke(start: cell))
                    .accessibilityElement(children: .ignore)
                    .accessibilityAddTraits(interactionsEnabled ? .isButton : [])
                    .accessibilityAction { if interactionsEnabled { onSelect(cell) } }
                    .accessibilityActions {
                        if interactionsEnabled, !game.puzzle.obstacles.contains(cell), let onSelectMode {
                            Button(String(localized: "Desenhar caminho")) { onSelectMode(cell, false) }
                            Button(String(localized: "Alternar marcação ×")) { onSelectMode(cell, true) }
                        }
                    }
                    .accessibilitySortPriority(Double((game.rows.count-cell.row)*(game.columns.count+1)-cell.col))
                    .offset(x: CGFloat(cell.col+1)*cellSide, y: CGFloat(cell.row+1)*cellSide)
                    .accessibilityIdentifier("cell-\(cell.row)-\(cell.col)")
                    .accessibilityLabel(BoardAccessibility.label(cell))
                    .accessibilityValue(BoardAccessibility.value(game: game, cell: cell, dogName: dogName, highlighted: highlighted.contains(cell)))
                    .accessibilityHint(!interactionsEnabled ? String(localized: "Tabuleiro somente para leitura") : game.puzzle.obstacles.contains(cell) ? String(localized: "Não pode fazer parte do caminho") : marking ? String(localized: "Toque duas vezes para alternar a marcação xis") : String(localized: "Toque duas vezes para continuar ou recuar o caminho"))
            }
            Path { p in
                for (index, cell) in game.path.enumerated() {
                    let center = CGPoint(x: (CGFloat(cell.col)+1.5)*cellSide, y: (CGFloat(cell.row)+1.5)*cellSide)
                    if index == 0 { p.move(to: center) } else { p.addLine(to: center) }
                }
            }.stroke(GardenTheme.trail, style: StrokeStyle(lineWidth: max(6, cellSide*0.2), lineCap: .round, lineJoin: .round))
                .frame(width: width, height: height).allowsHitTesting(false).accessibilityHidden(true)
            GardenHouse().padding(3)
                .frame(width: cellSide-4, height: cellSide-4)
                .offset(x: CGFloat(game.goal.col+1)*cellSide+2, y: CGFloat(game.goal.row+1)*cellSide+2)
                .allowsHitTesting(false).accessibilityHidden(true)
            Puppy(pose: walking ? .walking : game.won ? .happy : .idle).padding(3).frame(width: cellSide-4, height: cellSide-4)
                .rotationEffect(.degrees(wagging ? 12 : lean * 10))
                .animation(wagging ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true) : .spring(duration: 0.3), value: wagging)
                .animation(.spring(duration: 0.3), value: lean)
                .scaleEffect(enteredHouse ? 0.2 : 1).opacity(enteredHouse ? 0 : 1)
                .offset(y: enteredHouse ? -cellSide*0.25 : 0)
                .modifier(RouteArrival(path: game.path, side: cellSide, progress: arrivalProgress))
                .allowsHitTesting(false).accessibilityHidden(true)
        }.frame(width: width, height: height)
            .coordinateSpace(name: "puzzle-board")
            .onChange(of: touching) { _, active in
                if !active {
                    // onEnded commits first; recognizer cancellation has no onEnded.
                    DispatchQueue.main.async {
                        touchStart = nil
                        if !touching && strokeStarted { strokeStarted = false; onStrokeEnd(true) }
                    }
                }
            }
            .onDisappear { if strokeStarted { strokeStarted = false; onStrokeEnd(true) } }
    }
    /// Margot leans toward where the route is heading: -1 left, 1 right.
    private var lean: Double {
        guard let tip = game.path.last, !game.won else { return 0 }
        return Double((tip.col - game.start.col).signum())
    }
    /// Dragging draws; a touch that stays on its cell is a tap.
    private func stroke(start: Cell) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("puzzle-board"))
            .updating($touching) { _, active, _ in active = true }
            .onChanged { value in
                if touchStart == nil { touchStart = value.time }
                let cell = BoardHitTest.cell(x: value.location.x, y: value.location.y,
                    side: cellSide, rows: game.rows.count, columns: game.columns.count)
                if !strokeStarted {
                    guard cell != start else { return }
                    strokeStarted = true; onStrokeStart(start)
                }
                onStrokeMove(cell)
            }
            .onEnded { value in
                let held = value.time.timeIntervalSince(touchStart ?? value.time) >= 0.45
                touchStart = nil
                if strokeStarted { strokeStarted = false; onStrokeEnd(false) }
                else { onTap(start, held) }
            }
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
            PuzzleBoard(game: BoardSamples.partial, cellSide: 48).previewDisplayName(String(localized: "Parcial · 288 pt"))
            PuzzleBoard(game: BoardSamples.touching, cellSide: 60).previewDisplayName(String(localized: "Arestas explícitas"))
            PuzzleBoard(game: Game(puzzle: try! PuzzleFixtures.perimeter.makePuzzle()), cellSide: 48).previewDisplayName(String(localized: "Obstáculo"))
            PuzzleBoard(game: BoardSamples.partial, cellSide: 72, highlighted: [Cell(2,3)])
                .environment(\.dynamicTypeSize, .accessibility2).previewDisplayName(String(localized: "Texto ampliado"))
        }.padding(12).background(GardenTheme.background)
    }
}

/// Interpolate each edge separately so corners never cut across other cells.
private struct RouteArrival: AnimatableModifier {
    let path: [Cell]
    let side: CGFloat
    nonisolated var progress: Double
    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        let distance = min(max(progress, 0), 1) * Double(max(0, path.count-1))
        let index = min(Int(distance), path.count-1)
        let start = path[index]
        let end = path[min(index+1, path.count-1)]
        let fraction = distance - Double(index)
        content.offset(
            x: (CGFloat(start.col+1) + CGFloat(end.col-start.col)*fraction)*side+2,
            y: (CGFloat(start.row+1) + CGFloat(end.row-start.row)*fraction)*side+2)
    }
}

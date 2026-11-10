import SwiftUI

/// One game of Jardim, Canteiros, Casinhas, Sudoku or Patinhas, laid out like the walk:
/// thin bar, Margot's bubble, the largest board that fits, palette and toolbar.
struct CellGameScreen: View {
    @ObservedObject var session: GameSession
    let onHome: () -> Void
    let onSettings: () -> Void
    let onNext: () -> Void
    @State private var selected = 1
    @State private var flashed: Int?
    @State private var confirmingChange = false
    @State private var hintNote: String?

    var body: some View {
        if let attempt = session.cellAttempt {
            content(attempt)
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(GardenTheme.background)
        }
    }

    private func content(_ attempt: CellAttempt) -> some View {
        let puzzle = attempt.puzzle
        return VStack(spacing: 12) {
            GameTopBar(title: "\(puzzle.mode.title) · \(attempt.difficulty.title)", lives: attempt.lives, onHome: onHome, onSettings: onSettings)
            MargotBubble(text: bubble(attempt), symbol: session.message == nil ? nil : "exclamationmark.circle",
                         pose: attempt.won ? .happy : .idle, accessory: session.preferences.accessory)
            GeometryReader { space in
                CellBoard(attempt: attempt, house: session.pet.house, flashed: flashed, available: space.size,
                          onTap: tap, onHold: { session.markCell(at: $0) })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(attempt.canPlay)
            }
            if puzzle.palette.count > 1 && attempt.canPlay { palette(puzzle) }
            if attempt.defeated {
                Button(String(localized: "Tentar de novo"), systemImage: "arrow.clockwise") { session.restartCells() }
                    .buttonStyle(GardenButtonStyle(prominent: true))
            } else {
                HStack(spacing: 4) {
                    Button { hint() } label: {
                        Label(String(localized: "Dica · \(GameSession.cellHintPrice)"), systemImage: "lightbulb")
                    }.disabled(!attempt.canPlay)
                    Button(String(localized: "Outra fase"), systemImage: "arrow.triangle.2.circlepath") { confirmingChange = true }
                        .disabled(!attempt.canPlay || session.generating)
                }.buttonStyle(GardenIconButtonStyle())
                    .padding(4).background(GardenTheme.surface, in: RoundedRectangle(cornerRadius: GardenTheme.radius))
                    .overlay(RoundedRectangle(cornerRadius: GardenTheme.radius).strokeBorder(GardenTheme.border.opacity(0.5)))
            }
        }
        .padding(.horizontal, GardenTheme.spacing).padding(.bottom, 8)
        .frame(maxWidth: 560).frame(maxWidth: .infinity)
        .background(GardenTheme.background).foregroundStyle(GardenTheme.ink).tint(GardenTheme.accent)
        .overlay { if session.generating { ProgressView().controlSize(.large) } }
        .sheet(isPresented: $confirmingChange) {
            ChangeWalkSheet(isDaily: false, onConfirm: { confirmingChange = false; onNext() }, onCancel: { confirmingChange = false })
        }
        .sheet(isPresented: .constant(attempt.won)) {
            VictorySheet(dogName: session.dogName, paws: attempt.paws,
                         best: session.bestPaws[puzzle.id] ?? attempt.paws, isDaily: false, generating: session.generating,
                         reward: session.lastReward, onNext: onNext, onReplay: { session.restartCells() }, onHome: onHome)
        }
        .onAppear { selected = puzzle.palette.first ?? 1 }
    }

    private func bubble(_ attempt: CellAttempt) -> String {
        if let message = session.message { return message }
        if let hintNote { return hintNote }
        if attempt.won { return String(localized: "Prontinho! Que cabeça boa.") }
        if attempt.defeated { return String(localized: "As vidas acabaram. Vamos tentar de novo?") }
        return attempt.puzzle.mode.rules
    }

    private func palette(_ puzzle: CellPuzzle) -> some View {
        HStack(spacing: 6) {
            ForEach(puzzle.palette, id: \.self) { value in
                Button { selected = value } label: {
                    CellValueView(mode: puzzle.mode, value: value, given: false, house: session.pet.house)
                        .frame(width: 34, height: 34)
                        .frame(maxWidth: .infinity, minHeight: GardenTheme.minTarget)
                        .background(selected == value ? GardenTheme.sage : GardenTheme.surface, in: RoundedRectangle(cornerRadius: GardenTheme.cellRadius))
                        .overlay(RoundedRectangle(cornerRadius: GardenTheme.cellRadius).strokeBorder(selected == value ? GardenTheme.accent : GardenTheme.border.opacity(0.4), lineWidth: selected == value ? 2 : 1))
                }.buttonStyle(.plain)
                    .accessibilityLabel(CellValueView.label(mode: puzzle.mode, value: value))
                    .accessibilityAddTraits(selected == value ? .isSelected : [])
            }
        }
    }

    private func tap(_ index: Int) {
        guard let puzzle = session.cellAttempt?.puzzle else { return }
        let value = puzzle.palette.count > 1 ? selected : 1
        let before = session.cellAttempt?.mistakes ?? 0
        hintNote = nil
        session.placeCell(value, at: index)
        if (session.cellAttempt?.mistakes ?? 0) > before {
            flashed = index
            Task { try? await Task.sleep(for: .milliseconds(600)); if flashed == index { flashed = nil } }
        }
    }
    private func hint() {
        hintNote = session.revealCell() ? String(localized: "Olha uma casa certinha! (−\(GameSession.cellHintPrice) moedas)")
                                        : String(localized: "Faltam moedas para a dica.")
    }
}

/// The grid for every cell mode, with clue strips where the mode has them.
struct CellBoard: View {
    let attempt: CellAttempt
    let house: String
    let flashed: Int?
    let available: CGSize
    let onTap: (Int) -> Void
    let onHold: (Int) -> Void

    private var puzzle: CellPuzzle { attempt.puzzle }
    /// Clue strip sizes in cell units: nonogram runs stack, tents use one cell per line.
    private var leftUnits: CGFloat {
        switch puzzle.mode {
        case .nonogram: CGFloat(max(1, puzzle.rowClues.map(\.count).max() ?? 1)) * 0.6
        case .tents: 1
        default: 0
        }
    }
    private var topUnits: CGFloat {
        switch puzzle.mode {
        case .nonogram: CGFloat(max(1, puzzle.columnClues.map(\.count).max() ?? 1)) * 0.62
        case .tents: 1
        default: 0
        }
    }
    private var side: CGFloat {
        floor(min(available.width / (CGFloat(puzzle.size) + leftUnits), available.height / (CGFloat(puzzle.size) + topUnits)))
    }

    var body: some View {
        let s = side, n = puzzle.size
        VStack(alignment: .leading, spacing: 0) {
            if topUnits > 0 {
                HStack(alignment: .bottom, spacing: 0) {
                    Color.clear.frame(width: leftUnits * s, height: topUnits * s)
                    ForEach(0..<n, id: \.self) { c in columnClue(c, side: s) }
                }
            }
            HStack(alignment: .top, spacing: 0) {
                if leftUnits > 0 {
                    VStack(spacing: 0) { ForEach(0..<n, id: \.self) { r in rowClue(r, side: s) } }
                }
                grid(side: s)
            }
        }
    }

    private func grid(side s: CGFloat) -> some View {
        let n = puzzle.size
        return VStack(spacing: 0) {
            ForEach(0..<n, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<n, id: \.self) { c in cell(r * n + c, side: s) }
                }
            }
        }
        .overlay { BoxLines(puzzle: puzzle, side: s) }
        .overlay(Rectangle().strokeBorder(GardenTheme.ink.opacity(0.7), lineWidth: 2))
    }

    private func cell(_ index: Int, side s: CGFloat) -> some View {
        let given = puzzle.givens[index]
        let entry = attempt.entries[index]
        let value = given > 0 ? given : entry
        return ZStack {
            Rectangle().fill(background(index))
            if given == CellPuzzle.tree { TreeArt().padding(s * 0.1) }
            else if value != 0 { CellValueView(mode: puzzle.mode, value: value, given: given > 0, house: house).padding(s * (puzzle.mode == .nonogram ? 0 : 0.12)) }
            else if attempt.marks.contains(index) { Image(systemName: "xmark").font(.system(size: s * 0.4, weight: .semibold)).foregroundStyle(GardenTheme.secondary) }
            if flashed == index { Rectangle().fill(GardenTheme.error.opacity(0.45)) }
        }
        .frame(width: s, height: s)
        .overlay(Rectangle().strokeBorder(GardenTheme.border.opacity(0.5), lineWidth: 0.5))
        .contentShape(Rectangle())
        .onTapGesture { onTap(index) }
        .onLongPressGesture(minimumDuration: 0.45) { onHold(index) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Linha \(index / puzzle.size + 1), coluna \(index % puzzle.size + 1)"))
        .accessibilityValue(given == CellPuzzle.tree ? String(localized: "Árvore") : value != 0 ? CellValueView.label(mode: puzzle.mode, value: value)
                            : attempt.marks.contains(index) ? String(localized: "Marcada com xis") : String(localized: "Vazia"))
        .accessibilityAction { onTap(index) }
        .accessibilityAction(named: String(localized: "Alternar marcação ×")) { onHold(index) }
    }

    private func background(_ index: Int) -> Color {
        switch puzzle.mode {
        case .queens: return CellPalette.region(puzzle.regions[index])
        case .sudoku, .binary: return puzzle.givens[index] != 0 ? GardenTheme.sage.opacity(0.55) : GardenTheme.surface
        default: return GardenTheme.surface
        }
    }

    private func columnClue(_ c: Int, side s: CGFloat) -> some View {
        let clue = puzzle.columnClues[c]
        let met = puzzle.mode == .tents ? count(column: c) == clue.first : lineDone(column: c)
        return VStack(spacing: 0) {
            ForEach(Array((clue.isEmpty ? [0] : clue).enumerated()), id: \.offset) { _, v in
                Text("\(v)").font(.system(size: s * (puzzle.mode == .tents ? 0.5 : 0.42), weight: .semibold, design: .rounded)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
        }.frame(width: s, height: topUnits * s, alignment: .bottom)
            .foregroundStyle(met ? GardenTheme.secondary : GardenTheme.ink)
            .accessibilityElement(children: .ignore).accessibilityLabel(String(localized: "Coluna \(c + 1): \(clue.map(String.init).joined(separator: " "))"))
    }
    private func rowClue(_ r: Int, side s: CGFloat) -> some View {
        let clue = puzzle.rowClues[r]
        let met = puzzle.mode == .tents ? count(row: r) == clue.first : lineDone(row: r)
        return HStack(spacing: s * 0.12) {
            ForEach(Array((clue.isEmpty ? [0] : clue).enumerated()), id: \.offset) { _, v in
                Text("\(v)").font(.system(size: s * (puzzle.mode == .tents ? 0.5 : 0.42), weight: .semibold, design: .rounded)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
        }.frame(width: leftUnits * s, height: s, alignment: .trailing).padding(.trailing, 0)
            .foregroundStyle(met ? GardenTheme.secondary : GardenTheme.ink)
            .accessibilityElement(children: .ignore).accessibilityLabel(String(localized: "Linha \(r + 1): \(clue.map(String.init).joined(separator: " "))"))
    }
    private func count(row r: Int) -> Int { (0..<puzzle.size).filter { attempt.entries[r * puzzle.size + $0] == 1 }.count }
    private func count(column c: Int) -> Int { (0..<puzzle.size).filter { attempt.entries[$0 * puzzle.size + c] == 1 }.count }
    /// A nonogram line is done when every painted cell of the solution is painted.
    private func lineDone(row r: Int) -> Bool { (0..<puzzle.size).allSatisfy { attempt.entries[r * puzzle.size + $0] == puzzle.solution[r * puzzle.size + $0] } }
    private func lineDone(column c: Int) -> Bool { (0..<puzzle.size).allSatisfy { attempt.entries[$0 * puzzle.size + c] == puzzle.solution[$0 * puzzle.size + c] } }
}

/// Thick lines between sudoku boxes and between queens regions.
private struct BoxLines: View {
    let puzzle: CellPuzzle
    let side: CGFloat
    var body: some View {
        Path { p in
            let n = puzzle.size
            for r in 0..<n { for c in 0..<n {
                let i = r * n + c
                let x = CGFloat(c) * side, y = CGFloat(r) * side
                if c + 1 < n && split(i, i + 1, r, c, r, c + 1) { p.move(to: CGPoint(x: x + side, y: y)); p.addLine(to: CGPoint(x: x + side, y: y + side)) }
                if r + 1 < n && split(i, i + n, r, c, r + 1, c) { p.move(to: CGPoint(x: x, y: y + side)); p.addLine(to: CGPoint(x: x + side, y: y + side)) }
            } }
        }.stroke(GardenTheme.ink.opacity(0.75), lineWidth: 2).allowsHitTesting(false)
    }
    private func split(_ a: Int, _ b: Int, _ r1: Int, _ c1: Int, _ r2: Int, _ c2: Int) -> Bool {
        switch puzzle.mode {
        case .queens: return puzzle.regions[a] != puzzle.regions[b]
        case .sudoku: return r1 / puzzle.boxRows != r2 / puzzle.boxRows || c1 / puzzle.boxColumns != c2 / puzzle.boxColumns
        default: return false
        }
    }
}

enum CellPalette {
    static let regions: [Color] = [
        Color(red: 0.98, green: 0.84, blue: 0.80), Color(red: 0.82, green: 0.91, blue: 0.80), Color(red: 0.80, green: 0.88, blue: 0.97),
        Color(red: 0.99, green: 0.93, blue: 0.74), Color(red: 0.89, green: 0.84, blue: 0.96), Color(red: 0.80, green: 0.94, blue: 0.93),
        Color(red: 0.97, green: 0.86, blue: 0.93), Color(red: 0.90, green: 0.90, blue: 0.82), Color(red: 0.86, green: 0.95, blue: 0.82),
        Color(red: 0.95, green: 0.88, blue: 0.80), Color(red: 0.84, green: 0.86, blue: 0.94), Color(red: 0.93, green: 0.95, blue: 0.86),
    ]
    static func region(_ id: Int) -> Color { regions[((id % regions.count) + regions.count) % regions.count] }
}

/// How a placed value looks in each mode.
struct CellValueView: View {
    let mode: LogicMode
    let value: Int
    let given: Bool
    var house = "house.classic"
    var body: some View {
        switch mode {
        case .nonogram: Rectangle().fill(GardenTheme.accent)
        case .queens: Puppy(pose: .happy)
        case .tents: HouseModelArt(id: house)
        case .sudoku:
            GeometryReader { proxy in
                Text("\(value)").font(.system(size: proxy.size.height * 0.62, weight: given ? .heavy : .semibold, design: .rounded))
                    .foregroundStyle(given ? GardenTheme.ink : GardenTheme.trail)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .binary:
            ZStack {
                Circle().fill(value == 1 ? Color(red: 0.99, green: 0.93, blue: 0.80) : Color(red: 0.42, green: 0.30, blue: 0.24))
                Circle().strokeBorder(Color(red: 0.42, green: 0.30, blue: 0.24), lineWidth: 1.5)
                Image(systemName: "pawprint.fill").resizable().scaledToFit().padding(5)
                    .foregroundStyle(value == 1 ? Color(red: 0.62, green: 0.45, blue: 0.30) : Color(red: 0.99, green: 0.93, blue: 0.80))
            }.opacity(given ? 1 : 0.92)
        case .path: EmptyView()
        }
    }
    static func label(mode: LogicMode, value: Int) -> String {
        switch mode {
        case .nonogram: String(localized: "Pintada")
        case .queens: String(localized: "Cachorro")
        case .tents: String(localized: "Casinha")
        case .sudoku: String(localized: "Petisco \(value)")
        case .binary: value == 1 ? String(localized: "Patinha clara") : String(localized: "Patinha escura")
        case .path: ""
        }
    }
}

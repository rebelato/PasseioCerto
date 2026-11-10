import Foundation

/// The logic games Margot can play. `path` is the original walk; the others fill cells.
public enum LogicMode: String, CaseIterable, Codable, Sendable {
    case path, nonogram, queens, tents, sudoku, binary
    public var title: String {
        switch self {
        case .path: String(localized: "Passeio")
        case .nonogram: String(localized: "Jardim pintado")
        case .queens: String(localized: "Canteiros")
        case .tents: String(localized: "Casinhas e árvores")
        case .sudoku: String(localized: "Sudoku de petiscos")
        case .binary: String(localized: "Patinhas pareadas")
        }
    }
    public var symbol: String {
        switch self {
        case .path: "pawprint.fill"
        case .nonogram: "paintbrush.pointed.fill"
        case .queens: "square.grid.3x3.fill"
        case .tents: "house.fill"
        case .sudoku: "number.square.fill"
        case .binary: "circle.lefthalf.filled"
        }
    }
    /// The rules in one or two sentences, shown before playing.
    public var rules: String {
        switch self {
        case .path: String(localized: "Desenhe o caminho da Margot até a casinha. Os números contam as casas do caminho em cada linha e coluna.")
        case .nonogram: String(localized: "Pinte as casas: os números dizem, em ordem, os blocos de casas pintadas de cada linha e coluna. No fim aparece um desenho.")
        case .queens: String(localized: "Um cachorro por linha, coluna e canteiro, sem se encostarem nem na diagonal. Comece pelo que já está no lugar: ele elimina a linha, a coluna, o canteiro e as casas em volta.")
        case .tents: String(localized: "Cada árvore ganha uma casinha ao lado (não na diagonal). Os números contam as casinhas de cada linha e coluna, e duas casinhas nunca se encostam.")
        case .sudoku: String(localized: "Cada petisco aparece uma vez em cada linha, coluna e bloco.")
        case .binary: String(localized: "Patinhas claras e escuras: nunca três iguais seguidas, metade de cada em toda linha e coluna, e nenhuma linha ou coluna repetida.")
        }
    }
    /// Grid side for each difficulty.
    public func size(_ difficulty: Difficulty) -> Int {
        switch self {
        case .path: difficulty.size
        case .nonogram: [5, 8, 10, 12][difficulty.index]
        case .queens: [6, 7, 8, 9][difficulty.index]
        case .tents: [6, 8, 10, 12][difficulty.index]
        case .sudoku: [4, 6, 9, 9][difficulty.index]
        case .binary: [6, 8, 10, 12][difficulty.index]
        }
    }
}

extension Difficulty {
    var index: Int { Difficulty.allCases.firstIndex(of: self)! }
}

/// A square puzzle where the player places values in cells, with exactly one solution.
/// Values: nonogram/queens/tents use 1 (painted, dog, house); sudoku uses 1...n; binary 1 (light) and 2 (dark).
public struct CellPuzzle: Codable, Equatable, Sendable {
    public static let tree = -1
    public let id: String
    public let mode: LogicMode
    public let size: Int
    /// Row-major; 0 is "nothing here".
    public let solution: [Int]
    /// Fixed cells shown from the start (sudoku numbers, binary paws, tents' trees as `tree`); 0 elsewhere.
    public let givens: [Int]
    /// Queens: the region of each cell.
    public let regions: [Int]
    /// Nonogram runs, or tents' single count per line.
    public let rowClues: [[Int]]
    public let columnClues: [[Int]]
    /// Sudoku box shape.
    public let boxRows: Int
    public let boxColumns: Int

    public init(id: String, mode: LogicMode, size: Int, solution: [Int], givens: [Int]? = nil, regions: [Int] = [],
                rowClues: [[Int]] = [], columnClues: [[Int]] = [], boxRows: Int = 0, boxColumns: Int = 0) {
        self.id = id; self.mode = mode; self.size = size; self.solution = solution
        self.givens = givens ?? Array(repeating: 0, count: size * size)
        self.regions = regions; self.rowClues = rowClues; self.columnClues = columnClues
        self.boxRows = boxRows; self.boxColumns = boxColumns
    }
    public var count: Int { size * size }
    /// What the player can place in this mode.
    public var palette: [Int] {
        switch mode {
        case .sudoku: Array(1...size)
        case .binary: [1, 2]
        default: [1]
        }
    }
    /// Cells the player has to fill to finish.
    public func mustFill(_ index: Int) -> Bool {
        guard givens[index] == 0 else { return false }
        switch mode {
        case .sudoku, .binary: return true
        default: return solution[index] != 0
        }
    }
}

/// The player's progress on a cell puzzle. As in the walk, placing something the solution
/// doesn't have costs one of three lives and is refused; × marks are free.
public struct CellAttempt: Codable, Equatable, Sendable {
    public let puzzle: CellPuzzle
    public let difficulty: Difficulty
    public private(set) var entries: [Int]
    public private(set) var marks: Set<Int>
    public private(set) var mistakes: Int
    public init(puzzle: CellPuzzle, difficulty: Difficulty) {
        self.puzzle = puzzle; self.difficulty = difficulty
        entries = puzzle.givens.map { max(0, $0) }; marks = []; mistakes = 0
    }
    public var lives: Int { max(0, GameAttempt.maxLives - mistakes) }
    public var defeated: Bool { lives == 0 }
    public var paws: Int { max(1, GameAttempt.maxLives - mistakes) }
    public var won: Bool { (0..<puzzle.count).allSatisfy { !puzzle.mustFill($0) || entries[$0] == puzzle.solution[$0] } }
    public var canPlay: Bool { !won && !defeated }

    public enum Outcome: Equatable, Sendable { case placed, mistake, ignored }
    /// Places a value. A value the solution doesn't have there is a mistake.
    @discardableResult public mutating func place(_ value: Int, at index: Int) -> Outcome {
        guard canPlay, puzzle.givens.indices.contains(index), puzzle.givens[index] == 0, entries[index] == 0,
              puzzle.palette.contains(value) else { return .ignored }
        guard puzzle.solution[index] == value else { mistakes += 1; return .mistake }
        entries[index] = value
        marks.remove(index)
        return .placed
    }
    /// × as a reminder that a cell stays empty; never costs anything.
    public mutating func toggleMark(at index: Int) {
        guard canPlay, puzzle.givens.indices.contains(index), puzzle.givens[index] == 0, entries[index] == 0 else { return }
        if !marks.insert(index).inserted { marks.remove(index) }
    }
    /// Fills one correct cell (a paid hint). Returns the cell, or nil when nothing is left.
    public mutating func reveal(using pick: (Int) -> Int = { Int.random(in: 0..<$0) }) -> Int? {
        let open = (0..<puzzle.count).filter { puzzle.mustFill($0) && entries[$0] != puzzle.solution[$0] }
        guard canPlay, !open.isEmpty else { return nil }
        let index = open[pick(open.count)]
        entries[index] = puzzle.solution[index]; marks.remove(index)
        return index
    }
    public mutating func restart() { self = CellAttempt(puzzle: puzzle, difficulty: difficulty) }
}

/// Picks the generator for a mode.
public enum CellPuzzleGenerator {
    public static func generate(_ mode: LogicMode, _ difficulty: Difficulty, variation: UInt64) -> CellPuzzle? {
        var rng = SplitMix(seed: variation &* 0x9E3779B97F4A7C15 &+ UInt64(mode.hashSeed))
        let size = mode.size(difficulty)
        let id = "\(mode.rawValue)-v1-\(difficulty.rawValue)-\(variation)"
        switch mode {
        case .path: return nil
        case .nonogram: return Nonogram.generate(size: size, difficulty: difficulty, id: id, rng: &rng)
        case .queens: return Queens.generate(size: size, id: id, rng: &rng)
        case .tents: return Tents.generate(size: size, id: id, rng: &rng)
        case .sudoku: return Sudoku.generate(size: size, difficulty: difficulty, id: id, rng: &rng)
        case .binary: return Binary.generate(size: size, difficulty: difficulty, id: id, rng: &rng)
        }
    }
}

extension LogicMode {
    var hashSeed: Int { LogicMode.allCases.firstIndex(of: self)! * 7_919 }
}

/// Small, seedable random source shared by the cell generators.
public struct SplitMix: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func int(_ bound: Int) -> Int { Int(next() % UInt64(max(1, bound))) }
}

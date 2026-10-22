// Fixed snapshots: independent of future generator changes. Verified by both engines in tests.
public enum FallbackCatalog {
    public static let puzzles: [Puzzle] = [
        try! Puzzle(puzzleID: "reserve-v1-relaxed-0", rows: [0, 4, 2, 1, 0], columns: [1, 1, 1, 2, 2], start: Cell(1,0), goal: Cell(3,4), obstacles: [Cell(1,4), Cell(4,2)]),
        try! Puzzle(puzzleID: "reserve-v1-relaxed-1", rows: [2, 2, 3, 0, 0], columns: [0, 3, 2, 2, 0], start: Cell(1,3), goal: Cell(0,2), obstacles: [Cell(2,4), Cell(4,0)]),
        try! Puzzle(puzzleID: "reserve-v1-challenging-2", rows: [0, 2, 1, 3, 3], columns: [1, 4, 1, 2, 1], start: Cell(1,0), goal: Cell(3,4), obstacles: [Cell(0,3), Cell(4,0)]),
        try! Puzzle(puzzleID: "reserve-v1-challenging-5", rows: [3, 3, 1, 2, 0], columns: [3, 2, 2, 1, 1], start: Cell(0,4), goal: Cell(3,1), obstacles: [Cell(0,0), Cell(4,3), Cell(4,4)]),
    ]
    public static func puzzle(for level: PuzzleDifficulty, seed: UInt64) -> Puzzle {
        // Catalog order is stable and selection does not depend on randomized hashes.
        let offset = level == .relaxed ? 0 : 2
        return puzzles[offset + Int(seed % 2)]
    }
}

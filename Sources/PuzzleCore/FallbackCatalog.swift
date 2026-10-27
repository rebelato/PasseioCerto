import Foundation
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
    private static func reserve(_ json: String) -> Puzzle { try! JSONDecoder().decode(Puzzle.self, from: Data(json.utf8)) }
    /// Reserve walks per difficulty, from `Calibration walk-reserves`; certified in tests.
    public static let walks: [Difficulty: [Puzzle]] = [
        .easy: [
            reserve(#"{"columns":[1,2,2,3,5],"generatorVersion":1,"goal":{"col":0,"row":0},"obstacles":[],"puzzleID":"reserve-walk-v1-easy-0","rows":[5,4,2,1,1],"schemaVersion":2,"seed":1000,"start":{"col":4,"row":4}}"#),
            reserve(#"{"columns":[1,1,2,2,3],"generatorVersion":1,"goal":{"col":4,"row":4},"obstacles":[],"puzzleID":"reserve-walk-v1-easy-1","rows":[3,2,2,1,1],"schemaVersion":2,"seed":1001,"start":{"col":0,"row":0}}"#),
            reserve(#"{"columns":[5,1,1,1,1],"generatorVersion":1,"goal":{"col":0,"row":0},"obstacles":[],"puzzleID":"reserve-walk-v1-easy-2","rows":[1,1,1,1,5],"schemaVersion":2,"seed":1002,"start":{"col":4,"row":4}}"#),
        ],
        .medium: [
            reserve(#"{"columns":[7,2,1,1,1,1,1],"generatorVersion":1,"goal":{"col":1,"row":0},"hiddenGoal":true,"obstacles":[],"puzzleID":"reserve-walk-v1-medium-0","rows":[2,1,1,1,1,1,7],"schemaVersion":2,"seed":1000,"start":{"col":6,"row":6}}"#),
            reserve(#"{"columns":[1,1,1,1,1,2,7],"generatorVersion":1,"goal":{"col":0,"row":6},"hiddenGoal":true,"obstacles":[],"puzzleID":"reserve-walk-v1-medium-1","rows":[2,1,1,1,1,1,7],"schemaVersion":2,"seed":1001,"start":{"col":5,"row":0}}"#),
            reserve(#"{"columns":[3,1,2,4,1,1,2],"generatorVersion":1,"goal":{"col":6,"row":5},"hiddenGoal":true,"obstacles":[],"puzzleID":"reserve-walk-v1-medium-2","rows":[1,1,3,2,1,2,4],"schemaVersion":2,"seed":1002,"start":{"col":0,"row":0}}"#),
        ],
        .hard: [
            reserve(#"{"columns":[1,1,1,1,2,2,4,4,2,1,2,4,1,2,1],"generatorVersion":1,"goal":{"col":14,"row":14},"hiddenGoal":true,"obstacles":[],"puzzleID":"reserve-walk-v1-hard-0","rows":[5,2,2,1,1,2,1,1,2,3,2,1,1,3,2],"schemaVersion":2,"seed":1000,"start":{"col":0,"row":0}}"#),
            reserve(#"{"columns":[15,2,1,1,1,1,1,1,1,1,1,1,1,1,2],"generatorVersion":1,"goal":{"col":14,"row":1},"hiddenGoal":true,"obstacles":[],"puzzleID":"reserve-walk-v1-hard-1","rows":[15,2,1,1,1,1,1,1,1,1,1,1,1,1,2],"schemaVersion":2,"seed":1001,"start":{"col":1,"row":14}}"#),
            reserve(#"{"columns":[2,1,1,1,1,1,1,1,1,1,1,1,1,2,15],"generatorVersion":1,"goal":{"col":13,"row":14},"hiddenGoal":true,"obstacles":[],"puzzleID":"reserve-walk-v1-hard-2","rows":[15,2,1,1,1,1,1,1,1,1,1,1,1,1,2],"schemaVersion":2,"seed":1002,"start":{"col":0,"row":1}}"#),
        ],
        .expert: [
            reserve(#"{"columns":[1,2,1,3,1,1,1,5,1,1,2,3,1,1,1,1,9,1,1,2],"generatorVersion":1,"goal":{"col":19,"row":0},"hiddenGoal":true,"obstacles":[],"puzzleID":"reserve-walk-v1-expert-0","rows":[1,4,1,1,1,1,1,1,1,6,1,2,4,1,1,1,5,1,3,2],"schemaVersion":2,"seed":1000,"start":{"col":0,"row":19}}"#),
            reserve(#"{"columns":[1,1,1,1,1,5,5,5,4,2,1,3,1,1,1,4,1,1,2,2],"generatorVersion":1,"goal":{"col":0,"row":19},"hiddenGoal":true,"obstacles":[],"puzzleID":"reserve-walk-v1-expert-1","rows":[1,2,4,1,1,5,1,3,2,1,1,2,2,2,1,1,2,2,1,8],"schemaVersion":2,"seed":1001,"start":{"col":19,"row":0}}"#),
            reserve(#"{"columns":[2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,20],"generatorVersion":1,"goal":{"col":0,"row":1},"hiddenGoal":true,"obstacles":[],"puzzleID":"reserve-walk-v1-expert-2","rows":[20,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2],"schemaVersion":2,"seed":1002,"start":{"col":18,"row":19}}"#),
        ],
    ]
    public static func walk(for difficulty: Difficulty, variation: UInt64, id: String?) -> Puzzle? {
        guard let options = walks[difficulty], !options.isEmpty else { return nil }
        let reserve = options[Int(variation % UInt64(options.count))]
        return id.flatMap { try? reserve.renamed($0, seed: variation) } ?? reserve
    }
}

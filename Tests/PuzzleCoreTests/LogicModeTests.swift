import XCTest
@testable import PuzzleCore
final class LogicModeTests: XCTestCase {
    private func puzzles(_ mode: LogicMode, _ difficulties: [Difficulty] = Difficulty.allCases, variations: ClosedRange<UInt64> = 1...3) throws -> [CellPuzzle] {
        try difficulties.flatMap { d in try variations.map { v in
            let p = try XCTUnwrap(CellPuzzleGenerator.generate(mode, d, variation: v), "\(mode) \(d) \(v)")
            XCTAssertEqual(p.size, mode.size(d))
            XCTAssertEqual(CellPuzzleGenerator.generate(mode, d, variation: v), p, "Same variation, same puzzle")
            return p
        } }
    }

    func testQueensFollowTheRulesAndAreUnique() throws {
        for p in try puzzles(.queens) {
            let n = p.size
            let dogs = p.solution.indices.filter { p.solution[$0] == 1 }
            XCTAssertEqual(dogs.count, n)
            XCTAssertEqual(Set(dogs.map { $0 / n }).count, n, "One per row")
            XCTAssertEqual(Set(dogs.map { $0 % n }).count, n, "One per column")
            XCTAssertEqual(Set(dogs.map { p.regions[$0] }).count, n, "One per region")
            XCTAssertEqual(Set(p.regions).count, n)
            XCTAssertTrue(Queens.connected(p.regions, n))
            for a in dogs { for b in dogs where a < b { XCTAssertFalse(abs(a / n - b / n) <= 1 && abs(a % n - b % n) <= 1, "Dogs never touch") } }
            XCTAssertEqual(Queens.solve(n: n, regions: p.regions, limit: 2).count, 1)
        }
    }
    func testTentsFollowTheRulesAndAreUnique() throws {
        for p in try puzzles(.tents) {
            let n = p.size
            let houses = Set(p.solution.indices.filter { p.solution[$0] == 1 })
            let trees = p.givens.indices.filter { p.givens[$0] == CellPuzzle.tree }
            XCTAssertEqual(houses.count, trees.count)
            XCTAssertTrue(Tents.matches(houses, trees, n), "Every tree has its own house beside it")
            for h in houses { XCTAssertFalse(Tents.touches(h, houses.subtracting([h]), n)) }
            XCTAssertEqual(p.rowClues.map { $0[0] }, (0..<n).map { r in houses.filter { $0 / n == r }.count })
            XCTAssertEqual(Tents.solve(p, limit: 2).count, 1)
        }
    }
    func testSudokuIsValidAndUnique() throws {
        for p in try puzzles(.sudoku) {
            let n = p.size
            for i in 0..<n {
                XCTAssertEqual(Set((0..<n).map { p.solution[i * n + $0] }).count, n)
                XCTAssertEqual(Set((0..<n).map { p.solution[$0 * n + i] }).count, n)
            }
            for cell in p.givens.indices where p.givens[cell] != 0 { XCTAssertEqual(p.givens[cell], p.solution[cell]) }
            XCTAssertEqual(Sudoku.count(p.givens, n: n, box: (p.boxRows, p.boxColumns), limit: 2), 1)
        }
    }
    func testBinaryIsValidAndUnique() throws {
        for p in try puzzles(.binary, [.easy, .medium, .hard]) {
            let n = p.size
            for i in 0..<n {
                let row = (0..<n).map { p.solution[i * n + $0] }, column = (0..<n).map { p.solution[$0 * n + i] }
                for line in [row, column] {
                    XCTAssertEqual(line.filter { $0 == 1 }.count, n / 2)
                    XCTAssertFalse(zip(zip(line, line.dropFirst()), line.dropFirst(2)).contains { $0.0 == $0.1 && $0.1 == $1 }, "Never three alike")
                }
            }
            XCTAssertTrue(Binary.distinct(p.solution, n: n))
            XCTAssertEqual(Binary.count(p.givens, n: n, limit: 2), 1)
        }
    }
    func testNonogramCluesMatchAndLogicSolvesThem() throws {
        for p in try puzzles(.nonogram) {
            let n = p.size
            XCTAssertEqual(p.rowClues, (0..<n).map { r in Nonogram.runs((0..<n).map { p.solution[r * n + $0] }) })
            XCTAssertEqual(Nonogram.solve(rows: p.rowClues, columns: p.columnClues), p.solution)
        }
        XCTAssertEqual(Nonogram.solveLine([-1, -1, -1, -1, -1], [4]), [-1, 1, 1, 1, -1], "Overlap of a long block")
        XCTAssertNil(Nonogram.solveLine([1, 0, 1, -1, -1], [3]))
        XCTAssertEqual(Nonogram.solveLine([-1, -1, -1], []), [0, 0, 0])
    }

    func testAttemptsCostLivesOnMistakesAndFinish() throws {
        let p = try XCTUnwrap(CellPuzzleGenerator.generate(.queens, .easy, variation: 1))
        var attempt = CellAttempt(puzzle: p, difficulty: .easy)
        let wrong = try XCTUnwrap(p.solution.indices.first { p.solution[$0] == 0 })
        XCTAssertEqual(attempt.place(1, at: wrong), .mistake)
        XCTAssertEqual(attempt.lives, 2)
        attempt.toggleMark(at: wrong)
        XCTAssertTrue(attempt.marks.contains(wrong), "× is free")
        for cell in p.solution.indices where p.solution[cell] == 1 { XCTAssertEqual(attempt.place(1, at: cell), .placed) }
        XCTAssertTrue(attempt.won)
        XCTAssertEqual(attempt.paws, 2)
        XCTAssertEqual(attempt.place(1, at: wrong), .ignored, "Nothing changes after winning")
        attempt.restart()
        for _ in 0..<3 { attempt.place(1, at: wrong) }
        XCTAssertTrue(attempt.defeated)
    }
    func testGivensCannotBeChangedAndRevealFillsOneCell() throws {
        let p = try XCTUnwrap(CellPuzzleGenerator.generate(.sudoku, .easy, variation: 2))
        var attempt = CellAttempt(puzzle: p, difficulty: .easy)
        let given = try XCTUnwrap(p.givens.firstIndex { $0 != 0 })
        XCTAssertEqual(attempt.place(p.solution[given], at: given), .ignored)
        let open = p.givens.filter { $0 == 0 }.count
        let revealed = try XCTUnwrap(attempt.reveal(using: { _ in 0 }))
        XCTAssertEqual(attempt.entries[revealed], p.solution[revealed])
        XCTAssertEqual((0..<p.count).filter { p.mustFill($0) && attempt.entries[$0] != p.solution[$0] }.count, open - 1)
    }
}

final class CellSessionTests: XCTestCase {
    @MainActor func testFinishingACellPuzzlePaysOnceAndPersists() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("save.json")
        let s = GameSession(saveURL: url)
        await s.playCells(.queens, .medium)
        let p = try XCTUnwrap(s.cellAttempt?.puzzle)
        XCTAssertEqual(p.size, 7)
        let coins = s.pet.coins
        let wrong = try XCTUnwrap(p.solution.firstIndex(of: 0))
        s.placeCell(1, at: wrong)
        XCTAssertEqual(s.cellAttempt?.lives, 2)
        XCTAssertEqual(s.feedback?.kind, .conflict)
        let restored = GameSession(saveURL: url)
        XCTAssertEqual(restored.cellAttempt?.puzzle, p, "A cell game survives a relaunch")
        for cell in p.solution.indices where p.solution[cell] == 1 { s.placeCell(1, at: cell) }
        XCTAssertEqual(s.cellAttempt?.won, true)
        XCTAssertEqual(s.lastReward?.coins, 50, "Médio pays 25 per paw: 2 paws")
        XCTAssertEqual(s.pet.coins, coins + 50)
        s.restartCells()
        for cell in p.solution.indices where p.solution[cell] == 1 { s.placeCell(1, at: cell) }
        XCTAssertEqual(s.lastReward?.coins, 25, "Replays only pay the extra paw")
    }
    @MainActor func testHintsCostCoinsAndModeIsRemembered() async throws {
        let s = GameSession()
        s.setMode(.sudoku)
        XCTAssertEqual(s.preferences.mode, .sudoku)
        await s.playCells(.sudoku, .easy)
        let coins = s.pet.coins
        XCTAssertTrue(s.revealCell())
        XCTAssertEqual(s.pet.coins, coins - GameSession.cellHintPrice)
        while s.pet.coins >= GameSession.cellHintPrice, s.cellAttempt?.won == false { s.revealCell() }
        if s.cellAttempt?.won == false { XCTAssertFalse(s.revealCell(), "No hint without coins") }
    }
}

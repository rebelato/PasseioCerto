import Foundation

/// Casinhas e árvores (Tents): each tree gets a dog house next to it (not diagonally), the
/// numbers count houses per row and column, and no two houses touch, not even diagonally.
public enum Tents {
    public static func generate(size n: Int, id: String, rng: inout SplitMix, attempts: Int = 300) -> CellPuzzle? {
        for _ in 0..<attempts {
            var houses = Set<Int>(), trees = Set<Int>()
            let target = n * n / 5
            for cell in (0..<n * n).shuffled(using: &rng) where houses.count < target {
                guard !touches(cell, houses, n), !trees.contains(cell) else { continue }
                let spots = Queens.neighbours4(cell, n).filter { !houses.contains($0) && !trees.contains($0) }
                guard !spots.isEmpty else { continue }
                houses.insert(cell); trees.insert(spots[rng.int(spots.count)])
            }
            guard houses.count >= target * 3 / 4 else { continue }
            var solution = Array(repeating: 0, count: n * n), givens = Array(repeating: 0, count: n * n)
            for h in houses { solution[h] = 1 }
            for t in trees { givens[t] = CellPuzzle.tree }
            let rows = (0..<n).map { r in [(0..<n).filter { houses.contains(r * n + $0) }.count] }
            let columns = (0..<n).map { c in [(0..<n).filter { houses.contains($0 * n + c) }.count] }
            let puzzle = CellPuzzle(id: id, mode: .tents, size: n, solution: solution, givens: givens, rowClues: rows, columnClues: columns)
            if solve(puzzle, limit: 2).count == 1 { return puzzle }
        }
        return nil
    }

    /// Solutions as sets of house cells, up to `limit`.
    public static func solve(_ puzzle: CellPuzzle, limit: Int) -> [Set<Int>] {
        let n = puzzle.size
        let trees = (0..<puzzle.count).filter { puzzle.givens[$0] == CellPuzzle.tree }
        let rowTarget = puzzle.rowClues.map { $0.first ?? 0 }, columnTarget = puzzle.columnClues.map { $0.first ?? 0 }
        // Only free cells beside a tree can hold a house.
        let candidates = (0..<puzzle.count).filter { cell in
            puzzle.givens[cell] == 0 && Queens.neighbours4(cell, n).contains { puzzle.givens[$0] == CellPuzzle.tree }
        }
        var rowCount = Array(repeating: 0, count: n), columnCount = Array(repeating: 0, count: n)
        var rowLeft = Array(repeating: 0, count: n), columnLeft = Array(repeating: 0, count: n)
        for cell in candidates { rowLeft[cell / n] += 1; columnLeft[cell % n] += 1 }
        var houses = Set<Int>(), found: [Set<Int>] = []
        func search(_ i: Int) {
            guard found.count < limit else { return }
            if i == candidates.count {
                if rowCount == rowTarget && columnCount == columnTarget && houses.count == trees.count && matches(houses, trees, n) { found.append(houses) }
                return
            }
            let cell = candidates[i], r = cell / n, c = cell % n
            rowLeft[r] -= 1; columnLeft[c] -= 1
            defer { rowLeft[r] += 1; columnLeft[c] += 1 }
            if rowCount[r] < rowTarget[r] && columnCount[c] < columnTarget[c] && !touches(cell, houses, n) {
                houses.insert(cell); rowCount[r] += 1; columnCount[c] += 1
                search(i + 1)
                houses.remove(cell); rowCount[r] -= 1; columnCount[c] -= 1
            }
            // Skipping is only possible while the line can still reach its count.
            if rowCount[r] + rowLeft[r] >= rowTarget[r] && columnCount[c] + columnLeft[c] >= columnTarget[c] { search(i + 1) }
        }
        search(0)
        return found
    }
    static func touches(_ cell: Int, _ houses: Set<Int>, _ n: Int) -> Bool {
        let r = cell / n, c = cell % n
        for dr in -1...1 { for dc in -1...1 where dr != 0 || dc != 0 {
            let rr = r + dr, cc = c + dc
            if (0..<n).contains(rr) && (0..<n).contains(cc) && houses.contains(rr * n + cc) { return true }
        } }
        return false
    }
    /// Every tree gets its own house next to it (a perfect matching).
    static func matches(_ houses: Set<Int>, _ trees: [Int], _ n: Int) -> Bool {
        var partner = [Int: Int]()
        func assign(_ tree: Int, _ seen: inout Set<Int>) -> Bool {
            for house in Queens.neighbours4(tree, n) where houses.contains(house) && seen.insert(house).inserted {
                if partner[house] == nil || assign(partner[house]!, &seen) { partner[house] = tree; return true }
            }
            return false
        }
        for tree in trees { var seen = Set<Int>(); if !assign(tree, &seen) { return false } }
        return true
    }
}

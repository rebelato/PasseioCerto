import Foundation

/// Sudoku de petiscos: each treat once per row, column and box (4×4, 6×6 or 9×9).
public enum Sudoku {
    static func boxes(_ n: Int) -> (rows: Int, columns: Int) { n == 4 ? (2, 2) : n == 6 ? (2, 3) : (3, 3) }

    public static func generate(size n: Int, difficulty: Difficulty, id: String, rng: inout SplitMix) -> CellPuzzle? {
        let box = boxes(n)
        var grid = Array(repeating: 0, count: n * n)
        guard fill(&grid, n: n, box: box, rng: &rng) else { return nil }
        // Remove clues while the solution stays unique, down to the difficulty's target.
        let keep = n == 4 ? [8, 6, 5, 4][difficulty.index] : n == 6 ? [18, 14, 12, 10][difficulty.index] : [40, 34, 28, 22][difficulty.index]
        var givens = grid
        for cell in (0..<n * n).shuffled(using: &rng) where givens.filter({ $0 != 0 }).count > keep {
            let saved = givens[cell]
            givens[cell] = 0
            if count(givens, n: n, box: box, limit: 2) != 1 { givens[cell] = saved }
        }
        return CellPuzzle(id: id, mode: .sudoku, size: n, solution: grid, givens: givens, boxRows: box.rows, boxColumns: box.columns)
    }
    private static func candidates(_ grid: [Int], _ cell: Int, n: Int, box: (rows: Int, columns: Int)) -> [Int] {
        let r = cell / n, c = cell % n
        var used = Set<Int>()
        for i in 0..<n { used.insert(grid[r * n + i]); used.insert(grid[i * n + c]) }
        let br = r / box.rows * box.rows, bc = c / box.columns * box.columns
        for rr in br..<br + box.rows { for cc in bc..<bc + box.columns { used.insert(grid[rr * n + cc]) } }
        return (1...n).filter { !used.contains($0) }
    }
    private static func fill(_ grid: inout [Int], n: Int, box: (rows: Int, columns: Int), rng: inout SplitMix) -> Bool {
        guard let cell = grid.firstIndex(of: 0) else { return true }
        for v in candidates(grid, cell, n: n, box: box).shuffled(using: &rng) {
            grid[cell] = v
            if fill(&grid, n: n, box: box, rng: &rng) { return true }
        }
        grid[cell] = 0
        return false
    }
    /// Number of solutions, stopping at `limit`. Always tries the most constrained cell first.
    public static func count(_ start: [Int], n: Int, box: (rows: Int, columns: Int), limit: Int) -> Int {
        var grid = start, total = 0
        func search() {
            guard total < limit else { return }
            var best: (cell: Int, options: [Int])?
            for cell in grid.indices where grid[cell] == 0 {
                let options = candidates(grid, cell, n: n, box: box)
                if options.isEmpty { return }
                if best == nil || options.count < best!.options.count { best = (cell, options) }
                if options.count == 1 { break }
            }
            guard let best else { total += 1; return }
            for v in best.options { grid[best.cell] = v; search(); if total >= limit { break } }
            grid[best.cell] = 0
        }
        search()
        return total
    }
}

/// Patinhas pareadas (Takuzu): light and dark paws, never three alike in a row, half of each
/// in every row and column, and no two rows or columns the same.
public enum Binary {
    public static func generate(size n: Int, difficulty: Difficulty, id: String, rng: inout SplitMix) -> CellPuzzle? {
        var grid = Array(repeating: 0, count: n * n)
        guard fill(&grid, n: n, rng: &rng) else { return nil }
        let keepShare = [55, 45, 38, 32][difficulty.index]
        var givens = grid
        for cell in (0..<n * n).shuffled(using: &rng) where givens.filter({ $0 != 0 }).count * 100 > n * n * keepShare {
            let saved = givens[cell]
            givens[cell] = 0
            if count(givens, n: n, limit: 2) != 1 { givens[cell] = saved }
        }
        return CellPuzzle(id: id, mode: .binary, size: n, solution: grid, givens: givens)
    }
    /// Can `v` go at `cell` given the cells before it (row-major) and the rules?
    static func allowed(_ grid: [Int], _ cell: Int, _ v: Int, n: Int) -> Bool {
        let r = cell / n, c = cell % n
        func at(_ rr: Int, _ cc: Int) -> Int { grid[rr * n + cc] }
        if c >= 2 && at(r, c-1) == v && at(r, c-2) == v { return false }
        if r >= 2 && at(r-1, c) == v && at(r-2, c) == v { return false }
        if c + 1 < n && at(r, c+1) == v && (c >= 1 && at(r, c-1) == v || c + 2 < n && at(r, c+2) == v) { return false }
        if r + 1 < n && at(r+1, c) == v && (r >= 1 && at(r-1, c) == v || r + 2 < n && at(r+2, c) == v) { return false }
        if c >= 1 && c + 1 < n && at(r, c-1) == v && at(r, c+1) == v { return false }
        if r >= 1 && r + 1 < n && at(r-1, c) == v && at(r+1, c) == v { return false }
        if (0..<n).filter({ at(r, $0) == v }).count >= n / 2 { return false }
        if (0..<n).filter({ at($0, c) == v }).count >= n / 2 { return false }
        return true
    }
    /// Full rows and columns must differ from each other.
    static func distinct(_ grid: [Int], n: Int) -> Bool {
        var rows = Set<[Int]>(), columns = Set<[Int]>()
        for r in 0..<n {
            let row = Array(grid[r * n ..< r * n + n])
            if !row.contains(0) && !rows.insert(row).inserted { return false }
        }
        for c in 0..<n {
            let column = (0..<n).map { grid[$0 * n + c] }
            if !column.contains(0) && !columns.insert(column).inserted { return false }
        }
        return true
    }
    private static func fill(_ grid: inout [Int], n: Int, rng: inout SplitMix) -> Bool {
        guard let cell = grid.firstIndex(of: 0) else { return true }
        for v in [1, 2].shuffled(using: &rng) where allowed(grid, cell, v, n: n) {
            grid[cell] = v
            if distinct(grid, n: n), fill(&grid, n: n, rng: &rng) { return true }
        }
        grid[cell] = 0
        return false
    }
    public static func count(_ start: [Int], n: Int, limit: Int) -> Int {
        var total = 0
        func search(_ grid: [Int]) {
            guard total < limit else { return }
            var grid = grid
            // Fill every cell that has only one possible paw before guessing.
            var progress = true
            while progress {
                progress = false
                for cell in grid.indices where grid[cell] == 0 {
                    let options = [1, 2].filter { allowed(grid, cell, $0, n: n) }
                    if options.isEmpty { return }
                    if options.count == 1 { grid[cell] = options[0]; progress = true }
                }
            }
            guard distinct(grid, n: n) else { return }
            guard let cell = grid.firstIndex(of: 0) else { total += 1; return }
            for v in [1, 2] where allowed(grid, cell, v, n: n) {
                var next = grid; next[cell] = v
                search(next)
                if total >= limit { break }
            }
        }
        search(start)
        return total
    }
}

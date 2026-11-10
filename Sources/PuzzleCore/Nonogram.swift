import Foundation

/// Jardim pintado (Nonogram): each row and column lists, in order, its runs of painted cells.
/// Only pictures that line-by-line logic solves completely are used, which also makes them unique.
public enum Nonogram {
    public static func generate(size n: Int, difficulty: Difficulty, id: String, rng: inout SplitMix, attempts: Int = 400) -> CellPuzzle? {
        for _ in 0..<attempts {
            let picture = drawing(n, rng: &rng)
            let rows = (0..<n).map { r in runs((0..<n).map { picture[r * n + $0] }) }
            let columns = (0..<n).map { c in runs((0..<n).map { picture[$0 * n + c] }) }
            guard let solved = solve(rows: rows, columns: columns), solved == picture else { continue }
            return CellPuzzle(id: id, mode: .nonogram, size: n, solution: picture, rowClues: rows, columnClues: columns)
        }
        return nil
    }

    public static func runs(_ line: [Int]) -> [Int] {
        var result: [Int] = [], current = 0
        for value in line { if value != 0 { current += 1 } else if current > 0 { result.append(current); current = 0 } }
        if current > 0 { result.append(current) }
        return result
    }

    /// A blobby, mirror-symmetric picture: random seeds smoothed like a cellular automaton.
    private static func drawing(_ n: Int, rng: inout SplitMix) -> [Int] {
        var grid = (0..<n * n).map { _ in rng.int(100) < 52 ? 1 : 0 }
        for _ in 0..<2 {
            var next = grid
            for r in 0..<n { for c in 0..<n {
                var alive = 0
                for dr in -1...1 { for dc in -1...1 where dr != 0 || dc != 0 {
                    let rr = r + dr, cc = c + dc
                    if (0..<n).contains(rr) && (0..<n).contains(cc) { alive += grid[rr * n + cc] }
                } }
                next[r * n + c] = alive >= 5 ? 1 : alive <= 2 ? 0 : grid[r * n + c]
            } }
            grid = next
        }
        // Mirror left to right, so it reads like a figure.
        for r in 0..<n { for c in 0..<(n / 2) { grid[r * n + (n - 1 - c)] = grid[r * n + c] } }
        return grid
    }

    /// Line-by-line logic. Returns the picture when it is fully determined, nil otherwise.
    public static func solve(rows: [[Int]], columns: [[Int]]) -> [Int]? {
        let n = rows.count
        var grid = Array(repeating: -1, count: n * n) // -1 unknown, 0 empty, 1 painted
        var changed = true
        while changed {
            changed = false
            for r in 0..<n {
                let line = (0..<n).map { grid[r * n + $0] }
                guard let solved = solveLine(line, rows[r]) else { return nil }
                for c in 0..<n where solved[c] != line[c] { grid[r * n + c] = solved[c]; changed = true }
            }
            for c in 0..<n {
                let line = (0..<n).map { grid[$0 * n + c] }
                guard let solved = solveLine(line, columns[c]) else { return nil }
                for r in 0..<n where solved[r] != line[r] { grid[r * n + c] = solved[r]; changed = true }
            }
        }
        return grid.contains(-1) ? nil : grid
    }

    /// What every arrangement of `clue` consistent with `line` agrees on (nil if none fits).
    /// prefix[x][b]: cells 0..<x can hold blocks 0..<b; suffix[x][b]: cells x..<n can hold blocks b..<k.
    static func solveLine(_ line: [Int], _ clue: [Int]) -> [Int]? {
        let n = line.count, k = clue.count
        func canEmpty(_ i: Int) -> Bool { line[i] != 1 }
        func canPaint(_ from: Int, _ length: Int) -> Bool { (from..<from + length).allSatisfy { line[$0] != 0 } }
        var prefix = Array(repeating: Array(repeating: false, count: k + 1), count: n + 1)
        prefix[0][0] = true
        for x in 1...max(1, n) where x <= n {
            for b in 0...k {
                if canEmpty(x - 1) && prefix[x - 1][b] { prefix[x][b] = true; continue }
                guard b > 0 else { continue }
                let length = clue[b - 1], start = x - length
                guard start >= 0, canPaint(start, length) else { continue }
                if start == 0 { prefix[x][b] = b == 1 }
                else if canEmpty(start - 1) && prefix[start - 1][b - 1] { prefix[x][b] = true }
            }
        }
        var suffix = Array(repeating: Array(repeating: false, count: k + 1), count: n + 2)
        suffix[n][k] = true
        for x in stride(from: n - 1, through: 0, by: -1) {
            for b in stride(from: k, through: 0, by: -1) {
                if canEmpty(x) && suffix[x + 1][b] { suffix[x][b] = true; continue }
                guard b < k else { continue }
                let length = clue[b], end = x + length
                guard end <= n, canPaint(x, length) else { continue }
                if end == n { suffix[x][b] = b + 1 == k }
                else if canEmpty(end) && suffix[end + 1][b + 1] { suffix[x][b] = true }
            }
        }
        guard prefix[n][k] else { return nil }
        var paintable = Array(repeating: false, count: n), emptiable = Array(repeating: false, count: n)
        for i in 0..<n where canEmpty(i) {
            emptiable[i] = (0...k).contains { prefix[i][$0] && suffix[i + 1][$0] }
        }
        for b in 0..<k {
            let length = clue[b]
            guard length <= n else { return nil }
            for start in 0...(n - length) where canPaint(start, length) {
                let left = start == 0 ? b == 0 : canEmpty(start - 1) && prefix[start - 1][b]
                let end = start + length
                let right = end == n ? b + 1 == k : canEmpty(end) && suffix[end + 1][b + 1]
                if left && right { for i in start..<end { paintable[i] = true } }
            }
        }
        var result = line
        for i in 0..<n {
            switch (paintable[i], emptiable[i]) {
            case (true, false): result[i] = 1
            case (false, true): result[i] = 0
            case (false, false): return nil
            case (true, true): break
            }
        }
        return result
    }
}

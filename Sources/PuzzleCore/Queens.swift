import Foundation

/// Canteiros (Queens / Star Battle with one per line): one dog per row, column and region,
/// no two touching, not even diagonally.
public enum Queens {
    public static func generate(size n: Int, id: String, rng: inout SplitMix, attempts: Int = 400) -> CellPuzzle? {
        for _ in 0..<attempts {
            guard let columns = placement(n, rng: &rng) else { continue }
            var regions = grow(n, seeds: columns, rng: &rng)
            // Nudge regions until the dogs fit only one way, then give up on this placement.
            for _ in 0..<n * 6 {
                let solutions = solve(n: n, regions: regions, limit: 2)
                if solutions.count == 1 {
                    var solution = Array(repeating: 0, count: n * n)
                    for (r, c) in columns.enumerated() { solution[r * n + c] = 1 }
                    // One dog always starts in place; more are given only where deduction would stall.
                    let dogs = columns.enumerated().map { $0.offset * n + $0.element }.shuffled(using: &rng)
                    var givens = Array(repeating: 0, count: n * n)
                    givens[dogs[0]] = 1
                    for dog in dogs.dropFirst() where deduce(n: n, regions: regions, givens: givens) == nil { givens[dog] = 1 }
                    guard deduce(n: n, regions: regions, givens: givens) == solution else { break }
                    return CellPuzzle(id: id, mode: .queens, size: n, solution: solution, givens: givens, regions: regions)
                }
                guard let other = solutions.first(where: { $0 != columns }) else { break }
                // Hand a cell where the other solution puts a dog to a neighbouring region.
                let row = (0..<n).first { other[$0] != columns[$0] }!
                let cell = row * n + other[row]
                let owner = regions[cell]
                guard columns[row] != other[row], regions.firstIndex(of: owner) != nil else { break }
                let neighbours = neighbours4(cell, n).map { regions[$0] }.filter { $0 != owner }
                guard !neighbours.isEmpty, regions.filter({ $0 == owner }).count > 1,
                      !(0..<n).contains(where: { columns[$0] + $0 * n == cell }) else { break }
                regions[cell] = neighbours[rng.int(neighbours.count)]
                guard connected(regions, n) else { break }
            }
        }
        return nil
    }

    /// Solves with the deductions a person makes, from the given dogs. Returns the dogs grid when
    /// that finishes the puzzle, nil when deduction stalls (or the puzzle is broken).
    ///  - a row, column or region with a single possible cell gets the dog;
    ///  - a region whose possible cells all sit in one row (or column) empties the rest of that line,
    ///    and a line whose possible cells all sit in one region empties the rest of that region;
    ///  - a cell whose dog would leave some row, column or region with no possible cell is ruled out.
    public static func deduce(n: Int, regions: [Int], givens: [Int]) -> [Int]? {
        var state = Array(repeating: 0, count: n * n) // 0 open, 1 dog, -1 empty
        func groups() -> [[Int]] {
            (0..<n).map { r in (0..<n).map { r * n + $0 } } + (0..<n).map { c in (0..<n).map { $0 * n + c } }
                + Set(regions).sorted().map { region in regions.indices.filter { regions[$0] == region } }
        }
        let all = groups()
        func blocked(by dog: Int) -> [Int] {
            let r = dog / n, c = dog % n
            var cells = Set<Int>()
            for i in 0..<n { cells.insert(r * n + i); cells.insert(i * n + c) }
            for i in regions.indices where regions[i] == regions[dog] { cells.insert(i) }
            for dr in -1...1 { for dc in -1...1 {
                let rr = r + dr, cc = c + dc
                if (0..<n).contains(rr) && (0..<n).contains(cc) { cells.insert(rr * n + cc) }
            } }
            cells.remove(dog)
            return Array(cells)
        }
        func place(_ dog: Int) -> Bool {
            guard state[dog] != -1 else { return false }
            state[dog] = 1
            for cell in blocked(by: dog) { if state[cell] == 1 { return false }; state[cell] = -1 }
            return true
        }
        for cell in givens.indices where givens[cell] == 1 { guard place(cell) else { return nil } }
        var progress = true
        while progress {
            progress = false
            for group in all where !group.contains(where: { state[$0] == 1 }) {
                let open = group.filter { state[$0] == 0 }
                if open.isEmpty { return nil }
                if open.count == 1 { guard place(open[0]) else { return nil }; progress = true; continue }
                // Confined to one line or one region: clear the rest of it.
                for line in all where line != group && open.allSatisfy(line.contains) {
                    for cell in line where state[cell] == 0 && !group.contains(cell) { state[cell] = -1; progress = true }
                }
            }
            if progress { continue }
            for cell in state.indices where state[cell] == 0 {
                let cleared = Set(blocked(by: cell)).union([cell])
                let strands = all.contains { group in
                    !group.contains(where: { state[$0] == 1 }) && !group.contains(cell)
                        && group.allSatisfy { state[$0] != 0 || cleared.contains($0) }
                }
                if strands { state[cell] = -1; progress = true }
            }
        }
        guard state.filter({ $0 == 1 }).count == n else { return nil }
        return state.map { $0 == 1 ? 1 : 0 }
    }

    /// Solutions as the column of the dog in each row, up to `limit`.
    public static func solve(n: Int, regions: [Int], limit: Int) -> [[Int]] {
        var found: [[Int]] = []
        var columns = [Int]()
        var usedColumns = Set<Int>(), usedRegions = Set<Int>()
        func place(_ row: Int) {
            guard found.count < limit else { return }
            if row == n { found.append(columns); return }
            for c in 0..<n where !usedColumns.contains(c) && !usedRegions.contains(regions[row * n + c]) {
                if let last = columns.last, abs(last - c) <= 1 { continue }
                columns.append(c); usedColumns.insert(c); usedRegions.insert(regions[row * n + c])
                place(row + 1)
                columns.removeLast(); usedColumns.remove(c); usedRegions.remove(regions[row * n + c])
            }
        }
        place(0)
        return found
    }

    /// A random non-touching permutation (column per row).
    private static func placement(_ n: Int, rng: inout SplitMix) -> [Int]? {
        var columns = [Int]()
        func place(_ row: Int) -> Bool {
            if row == n { return true }
            for c in (0..<n).shuffled(using: &rng) where !columns.contains(c) && (columns.last.map { abs($0 - c) > 1 } ?? true) {
                columns.append(c)
                if place(row + 1) { return true }
                columns.removeLast()
            }
            return false
        }
        return place(0) ? columns : nil
    }
    /// Regions grown at random from each dog until every cell belongs to one.
    private static func grow(_ n: Int, seeds: [Int], rng: inout SplitMix) -> [Int] {
        var regions = Array(repeating: -1, count: n * n)
        var frontier: [Int] = []
        for (r, c) in seeds.enumerated() { regions[r * n + c] = r; frontier.append(r * n + c) }
        while !frontier.isEmpty {
            let pick = rng.int(frontier.count)
            let cell = frontier[pick]
            let open = neighbours4(cell, n).filter { regions[$0] == -1 }
            if open.isEmpty { frontier.remove(at: pick); continue }
            let next = open[rng.int(open.count)]
            regions[next] = regions[cell]
            frontier.append(next)
        }
        return regions
    }
    static func neighbours4(_ cell: Int, _ n: Int) -> [Int] {
        let r = cell / n, c = cell % n
        return [(r-1, c), (r+1, c), (r, c-1), (r, c+1)].filter { (0..<n).contains($0.0) && (0..<n).contains($0.1) }.map { $0.0 * n + $0.1 }
    }
    /// Every region is one connected piece.
    static func connected(_ regions: [Int], _ n: Int) -> Bool {
        for region in Set(regions) {
            let cells = regions.indices.filter { regions[$0] == region }
            var seen: Set<Int> = [cells[0]], pending = [cells[0]]
            while let cell = pending.popLast() {
                for next in neighbours4(cell, n) where regions[next] == region && seen.insert(next).inserted { pending.append(next) }
            }
            if seen.count != cells.count { return false }
        }
        return true
    }
}

import Foundation
import Darwin
import PuzzleCore

struct Sample: Codable {
    let seed: UInt64
    let puzzle: Puzzle
    let assessment: DifficultyAssessment
    let milliseconds: Double
    let candidates: Int
    let solverRejected: Int
    let logicRejected: Int
    let exactNodes: Int
    let fallback: Bool
}
struct Report: Codable {
    let peakProcessMemoryBytes: Int
    let platform: String
    let generatorVersion: Int
    let samples: [Sample]
}
if CommandLine.arguments.contains("walk-reserves") {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    for difficulty in Difficulty.allCases {
        var found = 0
        for variation in UInt64(1000)..<1100 where found < 3 {
            let r = WalkGenerator.generate(difficulty, variation: variation, id: "reserve-walk-v1-\(difficulty.rawValue)-\(found)")
            guard r.outcome == .generated, let p = r.puzzle else { continue }
            print("\(difficulty.rawValue)\t" + String(decoding: try encoder.encode(p), as: UTF8.self))
            found += 1
        }
    }
    exit(0)
}
if CommandLine.arguments.contains("sizes") {
    // Generation time and revealed pieces per difficulty (10 variations each).
    let clock = ContinuousClock()
    for difficulty in Difficulty.allCases {
        var times: [Double] = [], pieces: [Int] = [], candidates = 0, failed = 0, blocks = 0, linesSeen = 0, together = 0, multi = 0
        for variation in UInt64(1)...10 {
            let start = clock.now
            let r = WalkGenerator.generate(difficulty, variation: variation)
            let t = start.duration(to: clock.now).components
            times.append(Double(t.seconds)*1000 + Double(t.attoseconds)/1e15)
            candidates += r.candidates
            if let p = r.puzzle, let route = PuzzleSolution.route(for: p) {
                pieces.append(p.givenEdges.count)
                // Pieces per line: 1 means the line's route cells are all together.
                let lines = (0..<p.rows.count).map { r in route.filter { $0.row == r }.map(\.col) } + (0..<p.columns.count).map { c in route.filter { $0.col == c }.map(\.row) }
                for line in lines { let sorted = line.sorted(); blocks += 1 + zip(sorted, sorted.dropFirst()).filter { $1 - $0 > 1 }.count; linesSeen += 1
                    if sorted.count > 1 && zip(sorted, sorted.dropFirst()).allSatisfy({ $1 - $0 == 1 }) { together += 1; multi += 1 } else if sorted.count > 1 { multi += 1 } }
            } else { failed += 1 }
        }
        print("\(difficulty) median=\(times.sorted()[5])ms max=\(times.max()!)ms candidates=\(candidates) failed=\(failed) pieces=\(pieces) blocksPerLine=\(Double(blocks)/Double(max(1, linesSeen))) linesTogether=\(together)/\(multi)")
    }
    exit(0)
}
var samples: [Sample] = []
for seed in UInt64(0)..<100 {
    let clock = ContinuousClock()
    let start = clock.now
    let result = PuzzleGenerator.generate(seed: seed)
    let duration = start.duration(to: clock.now).components
    guard let puzzle = result.puzzle, let assessment = DifficultyClassifier.assess(puzzle) else {
        fatalError("Missing valid phase for seed \(seed)")
    }
    samples.append(Sample(seed: seed, puzzle: puzzle, assessment: assessment,
        milliseconds: Double(duration.seconds)*1000 + Double(duration.attoseconds)/1e15,
        candidates: result.candidates, solverRejected: result.rejectedBySolver,
        logicRejected: result.rejectedByLogic,
        exactNodes: ExactSolver.solve(puzzle: puzzle).visitedNodes, fallback: result.outcome == .fallback))
}
var usage = rusage()
getrusage(RUSAGE_SELF, &usage)
let report = Report(peakProcessMemoryBytes: usage.ru_maxrss, platform: ProcessInfo.processInfo.operatingSystemVersionString, generatorVersion: PuzzleGenerator.version, samples: samples)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
FileHandle.standardOutput.write(try encoder.encode(report))

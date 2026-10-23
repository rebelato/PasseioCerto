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
if CommandLine.arguments.contains("reserves") {
    // Two verified grids per world for FallbackCatalog.worlds, printed as JSON lines.
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    for world in World.allCases {
        var found = 0
        for attempt in UInt64(1)..<200 where found < 2 {
            let r = WorldGenerator.generate(WorldLevel(world: world, level: 3), attempt: attempt)
            guard r.outcome == .generated, var p = r.puzzle else { continue }
            p = try p.renamed("reserve-world-v1-\(world.rawValue)-\(found)", seed: nil)
            print("\(world.rawValue)\t" + String(decoding: try encoder.encode(p), as: UTF8.self))
            found += 1
        }
    }
    exit(0)
}
if CommandLine.arguments.contains("worlds") {
    // Per-level generation cost and outcome for the world progression.
    let clock = ContinuousClock()
    for world in World.allCases {
        for level in 0..<World.levelsPerWorld {
            let wl = WorldLevel(world: world, level: level)
            let start = clock.now
            let r = WorldGenerator.generate(wl)
            let ms = start.duration(to: clock.now).components
            let tier = r.puzzle.flatMap(LogicEngine.requiredTier) ?? -1
            print("\(world) \(level) outcome=\(r.outcome) ms=\(Double(ms.seconds)*1000 + Double(ms.attoseconds)/1e15) candidates=\(r.candidates) solver=\(r.rejectedBySolver) logic=\(r.rejectedByLogic) difficulty=\(r.rejectedByDifficulty) tier=\(tier)")
        }
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

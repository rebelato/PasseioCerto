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

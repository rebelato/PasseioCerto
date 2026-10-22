public enum PuzzleDifficulty: String, Codable, CaseIterable, Sendable {
    case relaxed, challenging
    public var title: String { self == .relaxed ? "Tranquilo" : "Desafiador" }
}
public struct DifficultyAssessment: Codable, Equatable, Sendable {
    public let version: Int
    public let level: PuzzleDifficulty
    public let deductions: Int
    public let ruleSwitches: Int
    public let connectivityDeductions: Int
}
public enum DifficultyClassifier {
    /// Provisional v1 heuristic, pending human calibration. Switches are trace
    /// alternations, not a claim about dependency depth or human reasoning time.
    public static func assess(_ puzzle: Puzzle) -> DifficultyAssessment? {
        let analysis = LogicEngine.analyze(puzzle: puzzle)
        guard analysis.outcome == .solved else { return nil }
        var last: Int?
        var switches = 0
        var connectivity = 0
        for deduction in analysis.deductions {
            let family: Int
            switch deduction.reason {
            case .rowComplete, .columnComplete: family = 0
            case .rowRemaining, .columnRemaining: family = 1
            case .unreachable: family = 2; connectivity += 1
            case .onlyContinuation: family = 3
            }
            if let last, last != family { switches += 1 }
            last = family
        }
        return DifficultyAssessment(version: 1,
            level: switches >= 8 || connectivity > 0 ? .challenging : .relaxed,
            deductions: analysis.deductions.count, ruleSwitches: switches,
            connectivityDeductions: connectivity)
    }
}

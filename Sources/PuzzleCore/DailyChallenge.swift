import Foundation

/// Civil date in the player's own time zone, so the challenge turns over at local midnight.
/// Policy v2: a Médio walk (hidden house, three lives). Persisted attempts always win over
/// regeneration, and v1 challenges already played keep their own id.
public struct DailyChallenge: Equatable, Sendable {
    public static let difficulty = Difficulty.medium
    public let dateKey: String
    public var id: String { "daily-v2-\(dateKey)" }
    public static func isDailyID(_ id: String) -> Bool { id.hasPrefix("daily-v1-") || id.hasPrefix("daily-v2-") }
    public let seed: UInt64
    public init(date: Date, timeZone: TimeZone = .current) {
        let c = Self.calendar(timeZone).dateComponents([.year, .month, .day], from: date)
        dateKey = String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        seed = UInt64(c.year!*10000 + c.month!*100 + c.day!)
    }
    /// Next local midnight after `date`, when a new challenge becomes available.
    public static func nextReset(after date: Date, timeZone: TimeZone = .current) -> Date {
        let calendar = calendar(timeZone)
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
    }
    /// Consecutive days with a finished challenge, ending today (or yesterday while today is still open).
    public static func streak(completed: Set<String>, today: Date, timeZone: TimeZone = .current) -> Int {
        let calendar = calendar(timeZone)
        var day = calendar.startOfDay(for: today)
        func done(_ day: Date) -> Bool {
            let key = DailyChallenge(date: day, timeZone: timeZone).dateKey
            return completed.contains("daily-v2-\(key)") || completed.contains("daily-v1-\(key)")
        }
        if !done(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var count = 0
        while done(day) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }
    private static func calendar(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

import Foundation

/// Civil date in the player's own time zone, so the challenge turns over at local midnight.
/// Keep v1 generation policy stable; persisted attempts always win over regeneration.
public struct DailyChallenge: Equatable, Sendable {
    public let dateKey: String
    public var id: String { "daily-v1-\(dateKey)" }
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
        if !completed.contains(DailyChallenge(date: day, timeZone: timeZone).id) {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var count = 0
        while completed.contains(DailyChallenge(date: day, timeZone: timeZone).id) {
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

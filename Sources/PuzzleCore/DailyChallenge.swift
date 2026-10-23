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
    private static func calendar(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

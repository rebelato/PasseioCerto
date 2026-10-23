import Foundation

/// Shared civil date in UTC, independent of locale, travel and daylight saving.
/// Keep v1 generation policy stable; persisted attempts always win over regeneration.
public struct DailyChallenge: Equatable, Sendable {
    public let dateKey: String
    public var id: String { "daily-v1-\(dateKey)" }
    public let seed: UInt64
    public init(date: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        dateKey = String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        seed = UInt64(c.year!*10000 + c.month!*100 + c.day!)
    }
}

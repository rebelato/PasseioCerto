import Foundation

/// Transient event, intentionally absent from saved games.
public struct GameFeedback: Equatable, Sendable {
    public enum Kind: Sendable { case action, conflict, victory }
    public let id = UUID()
    public let kind: Kind
    public init(_ kind: Kind) { self.kind = kind }
}

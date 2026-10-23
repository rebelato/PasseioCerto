import Foundation

/// Transient event, intentionally absent from saved games.
public struct GameFeedback: Equatable, Sendable {
    /// `step` and `clueMet` are live microfeedback while a stroke is drawn.
    public enum Kind: Sendable { case action, conflict, victory, step, clueMet }
    public let id = UUID()
    public let kind: Kind
    public init(_ kind: Kind) { self.kind = kind }
}

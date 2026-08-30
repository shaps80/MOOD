/// One directed collision report produced by `CollisionWorld2D.advance()`.
public struct Collision2D: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        /// Directed contact did not exist during the previous advance.
        case began
        /// Directed contact also existed during the previous advance.
        case changed
        /// Directed contact existed previously but no longer does.
        case ended
    }

    /// Collider whose mask requested this report.
    public let source: CollisionEndpoint2D
    /// Collider whose layer matched the source mask.
    public let target: CollisionEndpoint2D
    /// Relationship to the preceding call to `CollisionWorld2D.advance()`.
    public let phase: Phase
    /// Current geometric contact, or `nil` when `phase` is ``Phase/ended``.
    public let contact: Contact2D?

    package init(
        source: CollisionEndpoint2D,
        target: CollisionEndpoint2D,
        phase: Phase,
        contact: Contact2D?
    ) {
        self.source = source
        self.target = target
        self.phase = phase
        self.contact = contact
    }
}

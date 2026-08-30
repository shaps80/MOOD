/// Whether a collider is expected to move during simulation.
public enum CollisionMode: Sendable {
    /// Collider omitted from dynamic traversal and static-static testing.
    case `static`
    /// Collider included in centralized collision traversal.
    case dynamic
}

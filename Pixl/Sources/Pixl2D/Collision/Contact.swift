import Swift

/// The minimum translation needed to separate two overlapping 2D shapes.
///
/// `normal` points from the shape receiving the collision query toward the
/// other shape. Move the receiving shape in the opposite direction by
/// `depth` to resolve the overlap.
///
/// ```swift
/// if let contact = playerBounds.contact(with: wallBounds) {
///     playerPosition -= contact.normal * contact.depth
/// }
/// ```
public struct Contact2D: Sendable, Equatable {
    /// Unit direction from the queried shape toward the other shape.
    public let normal: Vec2

    /// Positive distance required to separate the overlapping shapes.
    public let depth: Float

    /// Creates a two-dimensional contact.
    /// - Parameters:
    ///   - normal: Unit direction from the queried shape toward the other shape.
    ///   - depth: Positive distance required to separate the shapes.
    public init(normal: Vec2, depth: Float) {
        self.normal = normal
        self.depth = depth
    }
}

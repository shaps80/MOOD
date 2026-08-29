import Pixl2D

/// A camera that produces a projection for a presentation surface.
public protocol Camera<Projection>: Sendable {
    associatedtype Projection: Sendable

    /// Returns the projection for a positive presentation size.
    func projection(in presentationSize: Vec2) -> Projection
}

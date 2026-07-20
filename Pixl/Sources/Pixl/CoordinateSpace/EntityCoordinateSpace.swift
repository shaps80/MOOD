import Swift

/// Coordinates relative to an entity's top-left local bounds.
///
/// Entity coordinates use a top-left origin. A point of `.zero` means the
/// target entity's top-left corner.
public struct EntityCoordinateSpace: CoordinateSpaceProtocol, Equatable, Sendable {
    /// Creates the typed entity-relative coordinate-space marker.
    public init() {}

    /// The stored `.entity` representation.
    public var coordinateSpace: CoordinateSpace {
        .entity
    }
}

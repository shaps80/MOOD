import Swift

/// Coordinates relative to an entity's top-left local bounds.
///
/// Entity coordinates use a top-left origin. A point of `.zero` means the
/// target entity's top-left corner.
public struct EntityCoordinateSpace: CoordinateSpaceProtocol, Equatable, Sendable {
    public init() {}

    public var coordinateSpace: CoordinateSpace {
        .entity
    }
}

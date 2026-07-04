import Swift

/// Describes what the camera should frame.
///
/// Anchors are deliberately gameplay-neutral. Pixl does not know about players,
/// bosses, rooms, pickups, or cutscenes. Game code supplies either a world point
/// or entity IDs, and the rig asks the game for each entity's bounds.
///
/// Entity anchor resolution:
///
/// ```text
/// entity A bounds          entity B bounds
/// +----------+             +----------+
/// |    a     |             |    b     |
/// +----------+             +----------+
///      \                       /
///       \                     /
///        +-------------------+
///        | union bounds      |
///        +-------------------+
///                 v
///          union center point
/// ```
///
/// Missing entity bounds are ignored. If no supplied entity resolves, the
/// camera keeps its previous resolved state for that frame.
public enum CameraAnchor: Equatable, Sendable {
    /// A fixed world-space point.
    case point(Vec2)

    /// One or more entities resolved through their world-space bounds.
    case entities([EntityID])

    func center(anchorBounds: (EntityID) -> Rect?) -> Vec2? {
        switch self {
        case .point(let point):
            return point
        case .entities(let ids):
            guard !ids.isEmpty else {
                return nil
            }

            var unionBounds: Rect?

            for id in ids {
                guard let bounds = anchorBounds(id) else {
                    continue
                }

                unionBounds = unionBounds.map { $0.union(bounds) } ?? bounds
            }

            return unionBounds?.center
        }
    }
}

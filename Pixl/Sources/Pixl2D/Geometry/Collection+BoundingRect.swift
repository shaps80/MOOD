/// Geometry conveniences for finite collections of two-dimensional points.
public extension Collection where Element == Vec2 {
    /// The smallest axis-aligned rectangle containing every point.
    ///
    /// Returns ``Rect/invalid`` when the collection is empty or contains a
    /// non-finite point.
    var boundingRect: Rect {
        guard let first,
              first.x.isFinite,
              first.y.isFinite
        else { return .invalid }

        var minimum = first
        var maximum = first
        for point in dropFirst() {
            guard point.x.isFinite, point.y.isFinite else { return .invalid }
            minimum = Vec2(
                Swift.min(minimum.x, point.x),
                Swift.min(minimum.y, point.y)
            )
            maximum = Vec2(
                Swift.max(maximum.x, point.x),
                Swift.max(maximum.y, point.y)
            )
        }
        return Rect(origin: minimum, size: maximum - minimum)
    }
}

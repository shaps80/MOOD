import Swift

public extension Rect {
    /// Returns the minimum translation needed to separate two overlapping rectangles.
    ///
    /// The returned normal points from this rectangle toward `other`. Moving
    /// this rectangle by `-contact.normal * contact.depth` resolves the
    /// overlap using the shortest axis. Equal horizontal and vertical depths
    /// deterministically choose the horizontal axis.
    ///
    /// ```swift
    /// if let contact = playerBounds.contact(with: wallBounds) {
    ///     playerPosition -= contact.normal * contact.depth
    /// }
    /// ```
    ///
    /// Returns `nil` when the rectangles are separated, merely touch at an
    /// edge or corner, or contain invalid coordinates. Touching has zero
    /// penetration and therefore does not produce a contact.
    ///
    /// - Parameter other: Rectangle to test against this rectangle.
    /// - Returns: Their minimum separating contact, or `nil` without positive overlap.
    func contact(with other: Rect) -> Contact2D? {
        guard intersects(other) else { return nil }

        let moveLeft = maxX - other.minX
        let moveRight = other.maxX - minX
        let moveDown = maxY - other.minY
        let moveUp = other.maxY - minY
        let hDepth = min(moveLeft, moveRight)
        let vDepth = min(moveDown, moveUp)

        let normal: Vec2
        let depth: Float

        if hDepth <= vDepth {
            depth = hDepth

            if moveLeft <= moveRight {
                normal = .init(1, 0)
            } else {
                normal = .init(-1, 0)
            }
        } else {
            depth = vDepth

            if moveDown <= moveUp {
                normal = .init(0, 1)
            } else {
                normal = .init(0, -1)
            }
        }

        return Contact2D(
            normal: normal,
            depth: depth
        )
    }
}

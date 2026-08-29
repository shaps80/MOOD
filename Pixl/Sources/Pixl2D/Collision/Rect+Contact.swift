import Swift

public extension Rect {
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

import Swift

extension Transform2D {
    /// Uniform scale retained by circle and capsule geometry after transformation.
    var analyticCollisionScale: Float {
        let xLengthSquared = (x.x * x.x) + (x.y * x.y)
        let yLengthSquared = (y.x * y.x) + (y.y * y.y)
        let orthogonality = (x.x * y.x) + (x.y * y.y)
        let tolerance = Swift.max(1, Swift.max(xLengthSquared, yLengthSquared))
            * 0.000_01

        precondition(
            xLengthSquared.isFinite
                && yLengthSquared.isFinite
                && orthogonality.isFinite
                && translation.x.isFinite
                && translation.y.isFinite
                && xLengthSquared > 0
                && abs(xLengthSquared - yLengthSquared) <= tolerance
                && abs(orthogonality) <= tolerance,
            "Circle2D and Capsule2D collision transforms require rotation, translation, and uniform scale"
        )
        return ((xLengthSquared + yLengthSquared) * 0.5).squareRoot()
    }

    func differs(from other: Transform2D) -> Bool {
        x != other.x || y != other.y || translation != other.translation
    }
}

import Swift

extension Segment {
    @inline(__always)
    func closestPoint(to point: Vec2) -> Vec2 {
        let direction = end - start
        let fraction = Swift.max(
            0,
            Swift.min(1, (point - start).dot(direction) / direction.dot(direction))
        )
        return start + (direction * fraction)
    }

    @inline(__always)
    func closestPoints(to other: Segment) -> (first: Vec2, second: Vec2) {
        let firstDirection = end - start
        let secondDirection = other.end - other.start
        let offset = start - other.start
        let firstLengthSquared = firstDirection.dot(firstDirection)
        let secondLengthSquared = secondDirection.dot(secondDirection)
        let directionsDot = firstDirection.dot(secondDirection)
        let firstOffsetDot = firstDirection.dot(offset)
        let secondOffsetDot = secondDirection.dot(offset)
        let denominator = (firstLengthSquared * secondLengthSquared)
            - (directionsDot * directionsDot)

        var firstFraction: Float
        if denominator != 0 {
            firstFraction = Swift.max(
                0,
                Swift.min(
                    1,
                    ((directionsDot * secondOffsetDot)
                        - (firstOffsetDot * secondLengthSquared)) / denominator
                )
            )
        } else {
            firstFraction = 0
        }

        var secondFraction = (directionsDot * firstFraction + secondOffsetDot)
            / secondLengthSquared
        if secondFraction < 0 {
            secondFraction = 0
            firstFraction = Swift.max(
                0,
                Swift.min(1, -firstOffsetDot / firstLengthSquared)
            )
        } else if secondFraction > 1 {
            secondFraction = 1
            firstFraction = Swift.max(
                0,
                Swift.min(
                    1,
                    (directionsDot - firstOffsetDot) / firstLengthSquared
                )
            )
        }

        return (
            start + (firstDirection * firstFraction),
            other.start + (secondDirection * secondFraction)
        )
    }
}

import Swift

public enum SpawnRegion: Hashable, Sendable {
    /// Places every particle at one world-space position.
    case point(Vec3)

    /// Distributes particles along a world-space line segment.
    case line(from: Vec3, to: Vec3)

    /// Distributes particles throughout a box centred on the origin.
    case box(size: Vec3)

    /// Distributes particles throughout a sphere centred on the origin.
    case sphere(radius: Float)

    func validate() {
        switch self {
        case let .point(position):
            precondition(position.isFinite)

        case let .line(start, end):
            precondition(start.isFinite && end.isFinite)

        case let .box(size):
            precondition(size.isFinite)
            precondition(size.x >= 0 && size.y >= 0 && size.z >= 0)

        case let .sphere(radius):
            precondition(radius.isFinite && radius >= 0)
        }
    }

    /// Samples a position using a stable sequence that forms part of the
    /// deterministic simulation contract.
    @inline(__always)
    func sample(
        using random: RandomSource,
        at address: UInt64
    ) -> Vec3 {
        switch self {
        case let .point(position):
            return position

        case let .line(start, end):
            let block = random.block(
                at: address,
                channel: .position
            )
            let fraction = RandomSource.unitFloat(from: block.x0)
            return start + (end - start) * fraction

        case let .box(size):
            let block = random.block(
                at: address,
                channel: .position
            )
            let halfSize = size / 2

            return [
                Self.component(from: block.x0, extent: halfSize.x),
                Self.component(from: block.x1, extent: halfSize.y),
                Self.component(from: block.x2, extent: halfSize.z),
            ]

        case let .sphere(radius):
            guard radius > 0 else { return .zero }

            var index: UInt32 = 0

            while true {
                let block = random.block(
                    at: address,
                    channel: .position,
                    index: index
                )
                let position: Vec3 = [
                    Self.component(from: block.x0, extent: 1),
                    Self.component(from: block.x1, extent: 1),
                    Self.component(from: block.x2, extent: 1),
                ]
                let xSquared = position.x * position.x
                let ySquared = position.y * position.y
                let zSquared = position.z * position.z
                let lengthSquared = xSquared + ySquared + zSquared

                if lengthSquared <= 1 {
                    return position * radius
                }

                index &+= 1
            }
        }
    }

    @inline(__always)
    private static func component(
        from word: UInt32,
        extent: Float
    ) -> Float {
        guard extent > 0 else { return 0 }
        return RandomSource.float(from: word, in: -extent..<extent)
    }
}

private extension Vec3 {
    var isFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite
    }
}

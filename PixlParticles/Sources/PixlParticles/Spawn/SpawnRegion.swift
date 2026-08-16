import Swift

public enum SpawnRegion: Hashable, Sendable {
    public enum Domain: Hashable, Sendable {
        case volume
        case surface
    }

    /// Places every particle at one world-space position.
    case point(Vec3)

    /// Distributes particles along a world-space line segment.
    case line(from: Vec3, to: Vec3)

    /// Distributes particles within a cube centred on the origin.
    case cube(size: Vec3, domain: Domain = .volume)

    /// Distributes particles within a sphere centred on the origin.
    case sphere(radius: Float, domain: Domain = .volume)

    func validate() {
        switch self {
        case let .point(position):
            precondition(position.isFinite)

        case let .line(start, end):
            precondition(start.isFinite && end.isFinite)

        case let .cube(size, domain):
            precondition(size.isFinite)
            precondition(size.x >= 0 && size.y >= 0 && size.z >= 0)

            if domain == .surface {
                precondition(Self.cubeFaceAreaSum(size).isFinite)
            }

        case let .sphere(radius, _):
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

        case let .cube(size, domain):
            let block = random.block(
                at: address,
                channel: .position
            )

            switch domain {
            case .volume:
                return Self.cubeVolume(size: size, block: block)
            case .surface:
                return Self.cubeSurface(size: size, block: block)
            }

        case let .sphere(radius, domain):
            guard radius > 0 else { return .zero }

            switch domain {
            case .volume:
                return Self.sphereVolume(
                    radius: radius,
                    using: random,
                    at: address
                )
            case .surface:
                return Self.sphereSurface(
                    radius: radius,
                    using: random,
                    at: address
                )
            }
        }
    }

    @inline(__always)
    private static func sphereVolume(
        radius: Float,
        using random: RandomSource,
        at address: UInt64
    ) -> Vec3 {
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

    /// Marsaglia's trig-free mapping from a unit disc onto a unit sphere.
    @inline(__always)
    private static func sphereSurface(
        radius: Float,
        using random: RandomSource,
        at address: UInt64
    ) -> Vec3 {
        var index: UInt32 = 0

        while true {
            let block = random.block(
                at: address,
                channel: .position,
                index: index
            )
            let x = component(from: block.x0, extent: 1)
            let y = component(from: block.x1, extent: 1)
            let lengthSquared = x * x + y * y

            if lengthSquared < 1 {
                let scale = 2 * (1 - lengthSquared).squareRoot()
                return [
                    x * scale * radius,
                    y * scale * radius,
                    (1 - 2 * lengthSquared) * radius,
                ]
            }

            index &+= 1
        }
    }

    @inline(__always)
    private static func cubeVolume(
        size: Vec3,
        block: Philox4x32.Counter
    ) -> Vec3 {
        let halfSize = size / 2

        return [
            component(from: block.x0, extent: halfSize.x),
            component(from: block.x1, extent: halfSize.y),
            component(from: block.x2, extent: halfSize.z),
        ]
    }

    @inline(__always)
    private static func cubeSurface(
        size: Vec3,
        block: Philox4x32.Counter
    ) -> Vec3 {
        let halfSize = size / 2
        let xyArea = size.x * size.y
        let xzArea = size.x * size.z
        let faceAreaSum = xyArea + xzArea + size.y * size.z

        guard faceAreaSum > 0 else {
            return cubeVolume(size: size, block: block)
        }

        let selection = RandomSource.unitFloat(from: block.x0) * faceAreaSum
        let side: Float = block.x3 & 1 == 0 ? -1 : 1

        if selection < xyArea {
            return [
                component(from: block.x1, extent: halfSize.x),
                component(from: block.x2, extent: halfSize.y),
                side * halfSize.z,
            ]
        }

        if selection < xyArea + xzArea {
            return [
                component(from: block.x1, extent: halfSize.x),
                side * halfSize.y,
                component(from: block.x2, extent: halfSize.z),
            ]
        }

        return [
            side * halfSize.x,
            component(from: block.x1, extent: halfSize.y),
            component(from: block.x2, extent: halfSize.z),
        ]
    }

    @inline(__always)
    private static func cubeFaceAreaSum(_ size: Vec3) -> Float {
        size.x * size.y + size.x * size.z + size.y * size.z
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

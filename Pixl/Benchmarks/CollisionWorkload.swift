import Pixl2D
import Swift

final class CollisionWorkload {
    static let staticColliderCount = 4_096
    static let dynamicColliderCount = 1_024
    static let colliderCount = staticColliderCount + dynamicColliderCount

    private let world = CollisionWorld2D()
    private var dynamicColliders: [ColliderID] = []
    private var frameIndex = 0

    init() {
        let worldLayer = CollisionLayer(0)
        let actorLayer = CollisionLayer(1)
        for index in 0..<Self.staticColliderCount {
            let x = Float(index % 64) * 4
            let y = Float(index / 64) * 4
            world.insert(
                bounds: Rect(x: x, y: y, width: 2, height: 2),
                mode: .static,
                layer: worldLayer,
                mask: .none
            )
        }
        dynamicColliders.reserveCapacity(Self.dynamicColliderCount)
        for index in 0..<Self.dynamicColliderCount {
            let x = Float(index % 32) * 8 + 0.5
            let y = Float(index / 32) * 8 + 0.5
            dynamicColliders.append(world.insert(
                bounds: Rect(x: x, y: y, width: 1.5, height: 1.5),
                mode: .dynamic,
                layer: actorLayer,
                mask: CollisionMask(worldLayer)
            ))
        }
    }

    func update() {
        frameIndex += 1
        let offset = Float(frameIndex % 8) * 0.05
        for index in dynamicColliders.indices {
            let x = Float(index % 32) * 8 + 0.5 + offset
            let y = Float(index / 32) * 8 + 0.5
            world.update(
                dynamicColliders[index],
                bounds: Rect(x: x, y: y, width: 1.5, height: 1.5)
            )
        }
    }

    func advance() -> CollisionResult {
        world.advance()
        var reportCount = 0
        var checksum: UInt64 = 0xcbf2_9ce4_8422_2325
        world.forEachCollision { collision in
            reportCount += 1
            checksum = mix(checksum, phaseValue(collision.phase))
            checksum = mix(checksum, UInt64(collision.source.bounds.origin.x.bitPattern))
            checksum = mix(checksum, UInt64(collision.source.bounds.origin.y.bitPattern))
            if let contact = collision.contact {
                checksum = mix(checksum, UInt64(contact.depth.bitPattern))
                checksum = mix(checksum, UInt64(contact.normal.x.bitPattern))
                checksum = mix(checksum, UInt64(contact.normal.y.bitPattern))
            }
        }
        return CollisionResult(reportCount: reportCount, checksum: checksum)
    }

    func query() -> Int {
        var hitCount = 0
        for index in 0..<64 {
            let x = Float(index % 8) * 32
            let y = Float(index / 8) * 32
            world.query(
                overlapping: Rect(x: x, y: y, width: 16, height: 16)
            ) { _ in
                hitCount += 1
                return true
            }
        }
        return hitCount
    }

    func rayCast() -> RayResult {
        var hitCount = 0
        var checksum: UInt64 = 0xcbf2_9ce4_8422_2325
        for index in 0..<32 {
            let ray = Ray2D(
                origin: Vec2(x: -1, y: Float(index) * 8 + 1),
                direction: Vec2(x: 1, y: 0)
            )
            if let result = world.rayCast(ray, maximumDistance: 300) {
                hitCount += 1
                checksum = mix(checksum, UInt64(result.hit.distance.bitPattern))
                checksum = mix(checksum, UInt64(result.hit.normal.x.bitPattern))
                checksum = mix(checksum, UInt64(result.hit.normal.y.bitPattern))
            }
        }
        return RayResult(hitCount: hitCount, checksum: checksum)
    }

    struct CollisionResult {
        let reportCount: Int
        let checksum: UInt64
    }

    struct RayResult {
        let hitCount: Int
        let checksum: UInt64
    }

    private func phaseValue(_ phase: Collision2D.Phase) -> UInt64 {
        switch phase {
        case .began: 1
        case .changed: 2
        case .ended: 3
        }
    }
}

private func mix(_ checksum: UInt64, _ value: UInt64) -> UInt64 {
    (checksum ^ value) &* 0x0000_0100_0000_01B3
}

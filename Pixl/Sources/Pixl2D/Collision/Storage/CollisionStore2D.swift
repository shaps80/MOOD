final class CollisionStore2D {
    private let broadPhase = DynamicAABBTree2D()
    private var pool = ColliderRecordPool2D()
    private let broadMargin: Float

    var count: Int { pool.count }

    init(broadMargin: Float = 0.1) {
        self.broadMargin = broadMargin
    }

    func insert(
        _ bounds: Rect,
        isDynamic: Bool,
        layer: CollisionLayer = 0,
        mask: CollisionMask = .all
    ) -> ColliderID {
        let broadBounds = bounds.padding(-broadMargin)
        let id = pool.allocate(
            bounds: bounds,
            broadBounds: broadBounds,
            layerBit: CollisionMask.bit(for: layer),
            mask: mask,
            isDynamic: isDynamic
        )
        let proxy = broadPhase.insert(broadBounds, userData: id.index)
        pool.records[Int(id.index)].proxy = proxy
        return id
    }

    func remove(_ id: ColliderID) {
        guard let index = pool.liveIndex(for: id) else { return }
        broadPhase.remove(pool.records[index].proxy)
        pool.free(id)
    }

    func bounds(for id: ColliderID) -> Rect? {
        guard let index = pool.liveIndex(for: id) else { return nil }
        return pool.records[index].bounds
    }

    func broadBounds(for id: ColliderID) -> Rect? {
        guard let index = pool.liveIndex(for: id) else { return nil }
        return pool.records[index].broadBounds
    }

    @discardableResult
    func update(_ id: ColliderID, bounds: Rect) -> Bool {
        guard let index = pool.liveIndex(for: id) else { return false }
        pool.records[index].bounds = bounds

        if Self.contains(pool.records[index].broadBounds, bounds) {
            return true
        }

        let broadBounds = bounds.padding(-broadMargin)
        pool.records[index].broadBounds = broadBounds
        return broadPhase.move(pool.records[index].proxy, to: broadBounds)
    }

    func query(
        overlapping bounds: Rect,
        mask: CollisionMask,
        _ visit: (ColliderID) -> Bool
    ) {
        guard !mask.isEmpty else { return }
        broadPhase.query(overlapping: bounds) { [self] _, candidateIndex in
            guard let candidateID = pool.liveID(at: candidateIndex) else {
                return true
            }
            let candidate = pool.records[Int(candidateIndex)]
            guard mask.contains(layerBit: candidate.layerBit),
                  bounds.intersects(candidate.bounds)
            else { return true }
            return visit(candidateID)
        }
    }

    func nearestRayHit(
        _ ray: Ray2D,
        mask: CollisionMask = .all,
        maximumDistance: Float = .infinity
    ) -> ColliderRayHit2D? {
        guard !mask.isEmpty else { return nil }
        var result: ColliderRayHit2D?

        broadPhase.rayCast(
            ray,
            maximumDistance: maximumDistance
        ) { [self] _, candidateIndex, clippedDistance in
            guard let candidateID = pool.liveID(at: candidateIndex),
                  mask.contains(
                    layerBit: pool.records[Int(candidateIndex)].layerBit
                  ),
                  let hit = pool.records[Int(candidateIndex)].bounds
                    .intersection(with: ray),
                  hit.distance < clippedDistance
            else { return .ignore }

            result = .init(collider: candidateID, hit: hit)
            return .clip(to: hit.distance)
        }

        return result
    }

    func generateContacts(into output: CollisionContactBuffer2D) {
        for dynamicSlot in 0..<pool.dynamicCount {
            let sourceIndex = Int(pool.dynamicIndices[dynamicSlot])
            let source = pool.records[sourceIndex]
            let sourceID = ColliderID(
                index: Int32(sourceIndex),
                generation: source.generation
            )

            broadPhase.query(overlapping: source.bounds) { [self] _, candidateIndex in
                guard candidateIndex != sourceID.index,
                      let candidateID = pool.liveID(at: candidateIndex)
                else { return true }

                let candidate = pool.records[Int(candidateIndex)]
                if candidate.isDynamic, candidateIndex < sourceID.index {
                    return true
                }
                guard let contact = source.bounds.contact(with: candidate.bounds) else {
                    return true
                }

                let sourceEndpoint = CollisionEndpoint2D(
                    collider: sourceID,
                    bounds: source.bounds
                )
                let candidateEndpoint = CollisionEndpoint2D(
                    collider: candidateID,
                    bounds: candidate.bounds
                )

                if source.mask.contains(layerBit: candidate.layerBit) {
                    output.append(
                        .init(
                            source: sourceEndpoint,
                            target: candidateEndpoint,
                            contact: contact
                        )
                    )
                }
                if candidate.mask.contains(layerBit: source.layerBit) {
                    output.append(
                        .init(
                            source: candidateEndpoint,
                            target: sourceEndpoint,
                            contact: .init(
                                normal: -contact.normal,
                                depth: contact.depth
                            )
                        )
                    )
                }
                return true
            }
        }
    }

    private static func contains(_ outer: Rect, _ inner: Rect) -> Bool {
        outer.minX <= inner.minX
            && outer.minY <= inner.minY
            && outer.maxX >= inner.maxX
            && outer.maxY >= inner.maxY
    }
}

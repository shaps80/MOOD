final class CollisionStore2D {
    private let broadPhase = DynamicAABBTree2D()
    private var pool = ColliderRecordPool2D()
    private let broadMargin: Float
    private var dirtyIndices: UnsafeMutablePointer<Int32>
    private var dirtyCount = 0
    private var dirtyCapacity = 16

    var count: Int { pool.count }

    init(broadMargin: Float = 0.1) {
        self.broadMargin = broadMargin
        dirtyIndices = .allocate(capacity: dirtyCapacity)
    }

    deinit {
        dirtyIndices.deinitialize(count: dirtyCount)
        dirtyIndices.deallocate()
    }

    func insert(
        _ bounds: Rect,
        isDynamic: Bool,
        layer: CollisionLayer = 0,
        mask: CollisionMask = .all
    ) -> ColliderID {
        insert(
            geometry: .rect(size: bounds.size),
            bounds: bounds,
            isDynamic: isDynamic,
            layer: layer,
            mask: mask
        )
    }

    func insert(
        _ polygon: Polygon2D,
        transform: Transform2D,
        isDynamic: Bool,
        layer: CollisionLayer = 0,
        mask: CollisionMask = .all
    ) -> ColliderID {
        let polygon = PolygonColliderGeometry2D(
            polygon,
            transform: transform
        )
        return insert(
            geometry: .polygon(polygon),
            bounds: polygon.bounds,
            isDynamic: isDynamic,
            layer: layer,
            mask: mask
        )
    }

    func insert(
        _ circle: Circle2D,
        transform: Transform2D,
        isDynamic: Bool,
        layer: CollisionLayer = 0,
        mask: CollisionMask = .all
    ) -> ColliderID {
        let circle = CircleColliderGeometry2D(circle, transform: transform)
        return insert(
            geometry: .circle(circle),
            bounds: circle.bounds,
            isDynamic: isDynamic,
            layer: layer,
            mask: mask
        )
    }

    func insert(
        _ capsule: Capsule2D,
        transform: Transform2D,
        isDynamic: Bool,
        layer: CollisionLayer = 0,
        mask: CollisionMask = .all
    ) -> ColliderID {
        let capsule = CapsuleColliderGeometry2D(
            capsule,
            transform: transform
        )
        return insert(
            geometry: .capsule(capsule),
            bounds: capsule.bounds,
            isDynamic: isDynamic,
            layer: layer,
            mask: mask
        )
    }

    private func insert(
        geometry: ColliderGeometry2D,
        bounds: Rect,
        isDynamic: Bool,
        layer: CollisionLayer,
        mask: CollisionMask
    ) -> ColliderID {
        let broadBounds = bounds.padding(-broadMargin)
        let id = pool.allocate(
            geometry: geometry,
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
        removeDirty(at: index)
        broadPhase.remove(pool.records[index].proxy)
        pool.free(id)
    }

    func bounds(for id: ColliderID) -> Rect? {
        synchronizeDirtyColliders()
        guard let index = pool.liveIndex(for: id) else { return nil }
        return pool.records[index].bounds
    }

    func broadBounds(for id: ColliderID) -> Rect? {
        synchronizeDirtyColliders()
        guard let index = pool.liveIndex(for: id) else { return nil }
        return pool.records[index].broadBounds
    }

    @discardableResult
    func update(_ id: ColliderID, bounds: Rect) -> Bool {
        guard let index = pool.liveIndex(for: id) else { return false }
        guard case .rect = pool.records[index].geometry else { return false }
        guard pool.records[index].bounds != bounds else { return true }
        pool.records[index].geometry = .rect(size: bounds.size)
        pool.records[index].bounds = bounds
        markDirty(index)
        return true
    }

    @discardableResult
    func update(_ id: ColliderID, transform: Transform2D) -> Bool {
        guard let index = pool.liveIndex(for: id) else { return false }
        switch pool.records[index].geometry {
        case .rect(let size):
            let bounds = Rect(
                center: .init(
                    transform.translation.x,
                    transform.translation.y
                ),
                size: size
            )
            guard pool.records[index].bounds != bounds else { return true }
            pool.records[index].bounds = bounds
        case .polygon(let polygon):
            guard polygon.setTransform(transform) else { return true }
        case .circle(let circle):
            guard circle.setTransform(transform) else { return true }
        case .capsule(let capsule):
            guard capsule.setTransform(transform) else { return true }
        }
        markDirty(index)
        return true
    }

    private func synchronize(index: Int, bounds: Rect) -> Bool {
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
        synchronizeDirtyColliders()
        let queryGeometry = ColliderGeometry2D.rect(size: bounds.size)
        broadPhase.query(overlapping: bounds) { [self] _, candidateIndex in
            guard let candidateID = pool.liveID(at: candidateIndex) else {
                return true
            }
            let candidate = pool.records[Int(candidateIndex)]
            guard mask.contains(layerBit: candidate.layerBit),
                  queryGeometry.contact(
                    bounds: bounds,
                    with: candidate.geometry,
                    bounds: candidate.bounds
                  ) != nil
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
        synchronizeDirtyColliders()
        var result: ColliderRayHit2D?

        broadPhase.rayCast(
            ray,
            maximumDistance: maximumDistance
        ) { [self] _, candidateIndex, clippedDistance in
            guard let candidateID = pool.liveID(at: candidateIndex),
                  mask.contains(
                    layerBit: pool.records[Int(candidateIndex)].layerBit
                  ),
                  let hit = pool.records[Int(candidateIndex)].geometry
                    .intersection(
                        bounds: pool.records[Int(candidateIndex)].bounds,
                        with: ray
                    ),
                  hit.distance < clippedDistance
            else { return .ignore }

            result = .init(collider: candidateID, hit: hit)
            return .clip(to: hit.distance)
        }

        return result
    }

    func generateContacts(into output: CollisionContactBuffer2D) {
        synchronizeDirtyColliders()
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
                let sourceWantsContact = source.mask.contains(
                    layerBit: candidate.layerBit
                )
                let candidateWantsContact = candidate.mask.contains(
                    layerBit: source.layerBit
                )
                guard sourceWantsContact || candidateWantsContact else {
                    return true
                }
                guard let contact = source.geometry.contact(
                    bounds: source.bounds,
                    with: candidate.geometry,
                    bounds: candidate.bounds
                ) else {
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

                if sourceWantsContact {
                    output.append(
                        .init(
                            source: sourceEndpoint,
                            target: candidateEndpoint,
                            contact: contact
                        )
                    )
                }
                if candidateWantsContact {
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

    private func markDirty(_ index: Int) {
        guard pool.records[index].dirtySlot == -1 else { return }
        if dirtyCount == dirtyCapacity { growDirtyIndices() }
        dirtyIndices.advanced(by: dirtyCount).initialize(to: Int32(index))
        pool.records[index].dirtySlot = Int32(dirtyCount)
        dirtyCount += 1
    }

    private func removeDirty(at index: Int) {
        let slot = pool.records[index].dirtySlot
        guard slot >= 0 else { return }
        let slotIndex = Int(slot)
        let lastSlot = dirtyCount - 1
        let movedIndex = dirtyIndices[lastSlot]
        dirtyIndices[slotIndex] = movedIndex
        pool.records[Int(movedIndex)].dirtySlot = Int32(slotIndex)
        dirtyIndices.advanced(by: lastSlot).deinitialize(count: 1)
        dirtyCount = lastSlot
        pool.records[index].dirtySlot = -1
    }

    func synchronizeDirtyColliders() {
        for slot in 0..<dirtyCount {
            let index = Int(dirtyIndices[slot])
            pool.records[index].dirtySlot = -1
            switch pool.records[index].geometry {
            case .rect:
                _ = synchronize(
                    index: index,
                    bounds: pool.records[index].bounds
                )
            case .polygon(let polygon):
                polygon.synchronize()
                _ = synchronize(index: index, bounds: polygon.bounds)
            case .circle(let circle):
                circle.synchronize()
                _ = synchronize(index: index, bounds: circle.bounds)
            case .capsule(let capsule):
                capsule.synchronize()
                _ = synchronize(index: index, bounds: capsule.bounds)
            }
        }
        dirtyIndices.deinitialize(count: dirtyCount)
        dirtyCount = 0
    }

    private func growDirtyIndices() {
        let newCapacity = dirtyCapacity + max(dirtyCapacity / 2, 1)
        let newIndices = UnsafeMutablePointer<Int32>.allocate(
            capacity: newCapacity
        )
        newIndices.moveInitialize(from: dirtyIndices, count: dirtyCount)
        dirtyIndices.deallocate()
        dirtyIndices = newIndices
        dirtyCapacity = newCapacity
    }
}

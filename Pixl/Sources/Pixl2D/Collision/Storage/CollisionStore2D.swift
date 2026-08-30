final class CollisionStore2D {
    private let broadPhase = DynamicAABBTree2D()
    private var pool = ColliderRecordPool2D()
    private let broadMargin: Float

    var count: Int { pool.count }

    init(broadMargin: Float = 0.1) {
        self.broadMargin = broadMargin
    }

    func insert(_ bounds: Rect, isDynamic: Bool) -> ColliderID {
        let broadBounds = bounds.padding(-broadMargin)
        let id = pool.allocate(
            bounds: bounds,
            broadBounds: broadBounds,
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

    @discardableResult
    func contacts(
        for id: ColliderID,
        _ visit: (ColliderID, Contact2D) -> Bool
    ) -> Int {
        guard let sourceIndex = pool.liveIndex(for: id) else { return 0 }
        let source = pool.records[sourceIndex]
        var contactCount = 0

        broadPhase.query(overlapping: source.bounds) { [self] _, candidateIndex in
            guard candidateIndex != id.index,
                  let candidateID = pool.liveID(at: candidateIndex)
            else { return true }

            let candidate = pool.records[Int(candidateIndex)]
            guard source.isDynamic || candidate.isDynamic,
                  let contact = source.bounds.contact(with: candidate.bounds)
            else { return true }

            contactCount += 1
            return visit(candidateID, contact)
        }

        return contactCount
    }

    func nearestRayHit(_ ray: Ray2D) -> ColliderRayHit2D? {
        var result: ColliderRayHit2D?

        broadPhase.rayCast(ray) { [self] _, candidateIndex, maximumDistance in
            guard let candidateID = pool.liveID(at: candidateIndex),
                  let hit = pool.records[Int(candidateIndex)]
                    .bounds.intersection(with: ray),
                  hit.distance < maximumDistance
            else { return .ignore }

            result = .init(collider: candidateID, hit: hit)
            return .clip(to: hit.distance)
        }

        return result
    }

    private static func contains(_ outer: Rect, _ inner: Rect) -> Bool {
        outer.minX <= inner.minX
            && outer.minY <= inner.minY
            && outer.maxX >= inner.maxX
            && outer.maxY >= inner.maxY
    }
}

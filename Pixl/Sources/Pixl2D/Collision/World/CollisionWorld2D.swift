/// Game-owned storage and centralized collision detection for 2D bounds.
public final class CollisionWorld2D {
    private let store: CollisionStore2D
    private let currentContacts = CollisionContactBuffer2D()
    private let previousContacts = CollisionContactBuffer2D()
    private let reports = CollisionReportBuffer2D()

    /// Number of currently live colliders.
    public var count: Int { store.count }

    /// Creates an empty game-owned collision world.
    public init() {
        store = .init()
    }

    package init(broadMargin: Float) {
        store = .init(broadMargin: broadMargin)
    }

    /// Inserts exact world-space bounds and returns their stable opaque identity.
    @discardableResult
    public func insert(
        bounds: Rect,
        mode: CollisionMode,
        layer: CollisionLayer,
        mask: CollisionMask = .all
    ) -> ColliderID {
        store.insert(
            bounds,
            isDynamic: mode == .dynamic,
            layer: layer,
            mask: mask
        )
    }

    /// Inserts polygon geometry with its model-to-world transform.
    ///
    /// Polygon normalization and convex decomposition are retained from the
    /// immutable geometry. Transformed vertices and exact world-space bounds
    /// are calculated once here and rebuilt only by ``update(_:transform:)``.
    @discardableResult
    public func insert(
        _ polygon: Polygon2D,
        transform: Transform2D = .identity,
        mode: CollisionMode,
        layer: CollisionLayer,
        mask: CollisionMask = .all
    ) -> ColliderID {
        store.insert(
            polygon,
            transform: transform,
            isDynamic: mode == .dynamic,
            layer: layer,
            mask: mask
        )
    }

    /// Inserts local-space circle geometry with its model-to-world transform.
    ///
    /// Circle collision transforms support translation, rotation, and uniform
    /// scale. Non-uniform scale and shear do not preserve a circle.
    @discardableResult
    public func insert(
        _ circle: Circle2D,
        transform: Transform2D = .identity,
        mode: CollisionMode,
        layer: CollisionLayer,
        mask: CollisionMask = .all
    ) -> ColliderID {
        store.insert(
            circle,
            transform: transform,
            isDynamic: mode == .dynamic,
            layer: layer,
            mask: mask
        )
    }

    /// Inserts local-space capsule geometry with its model-to-world transform.
    ///
    /// Capsule collision transforms support translation, rotation, and uniform
    /// scale. Non-uniform scale and shear do not preserve circular caps.
    @discardableResult
    public func insert(
        _ capsule: Capsule2D,
        transform: Transform2D = .identity,
        mode: CollisionMode,
        layer: CollisionLayer,
        mask: CollisionMask = .all
    ) -> ColliderID {
        store.insert(
            capsule,
            transform: transform,
            isDynamic: mode == .dynamic,
            layer: layer,
            mask: mask
        )
    }

    /// Removes a collider. Stale identities are ignored.
    public func remove(_ collider: ColliderID) {
        store.remove(collider)
    }

    /// Returns current exact world-space bounds for a live collider.
    public func bounds(for collider: ColliderID) -> Rect? {
        store.bounds(for: collider)
    }

    /// Updates exact world-space rectangle bounds. Stale identities and
    /// non-rectangle colliders are ignored.
    public func update(_ collider: ColliderID, bounds: Rect) {
        store.update(collider, bounds: bounds)
    }

    /// Updates a collider's model-to-world transform and invalidates its cache.
    ///
    /// Polygon geometry applies the complete affine transform. Circles and
    /// capsules accept translation, rotation, and uniform scale. Rectangles
    /// use translation only until oriented rectangle collision is introduced.
    /// Stale identities are ignored.
    public func update(_ collider: ColliderID, transform: Transform2D) {
        store.update(collider, transform: transform)
    }

    /// Advances collision detection by one fixed simulation tick.
    ///
    /// This is the only operation that performs centralized pair generation,
    /// exact contact testing, and collision-phase reporting. Games that do not
    /// call it pay no per-tick collision-detection cost.
    public func advance() {
        currentContacts.reset()
        reports.reset()
        store.generateContacts(into: currentContacts)
        currentContacts.sort()
        mergeContactPhases()
        currentContacts.swapStorage(with: previousContacts)
    }

    /// Advances collision detection and visits each directed report.
    ///
    /// Return the corrected model-to-world transform for the report's source
    /// collider when handling the collision changes it. The collision world
    /// coalesces repeated changes and synchronizes dirty collision geometry
    /// once after every report has been delivered. Return `nil` when the
    /// source transform did not change.
    public func advance(
        _ body: (Collision2D) -> Transform2D?
    ) {
        advance()
        for index in 0..<reports.count {
            let report = reports.reports[index]
            if let transform = body(report) {
                store.update(report.source.collider, transform: transform)
            }
        }
        store.synchronizeDirtyColliders()
    }

    /// Visits directed reports produced by the latest call to ``advance()``.
    public func forEachCollision(_ body: (Collision2D) -> Void) {
        for index in 0..<reports.count {
            body(reports.reports[index])
        }
    }

    /// Visits exact colliders overlapping `bounds` whose layer is in `mask`.
    /// Return `false` from `visit` to terminate traversal early.
    public func query(
        overlapping bounds: Rect,
        mask: CollisionMask = .all,
        _ visit: (ColliderID) -> Bool
    ) {
        store.query(overlapping: bounds, mask: mask, visit)
    }

    /// Returns the nearest exact ray hit whose collider layer is in `mask`.
    public func rayCast(
        _ ray: Ray2D,
        mask: CollisionMask = .all,
        maximumDistance: Float = .infinity
    ) -> ColliderRayHit2D? {
        store.nearestRayHit(
            ray,
            mask: mask,
            maximumDistance: maximumDistance
        )
    }

    private func mergeContactPhases() {
        var currentIndex = 0
        var previousIndex = 0

        while currentIndex < currentContacts.count
            || previousIndex < previousContacts.count
        {
            if currentIndex == currentContacts.count {
                appendEnded(previousContacts.records[previousIndex])
                previousIndex += 1
                continue
            }
            if previousIndex == previousContacts.count {
                appendCurrent(currentContacts.records[currentIndex], phase: .began)
                currentIndex += 1
                continue
            }

            let current = currentContacts.records[currentIndex]
            let previous = previousContacts.records[previousIndex]
            if current.hasSameKey(as: previous) {
                appendCurrent(current, phase: .changed)
                currentIndex += 1
                previousIndex += 1
            } else if current < previous {
                appendCurrent(current, phase: .began)
                currentIndex += 1
            } else {
                appendEnded(previous)
                previousIndex += 1
            }
        }
    }

    private func appendCurrent(
        _ record: CollisionContactRecord2D,
        phase: Collision2D.Phase
    ) {
        reports.append(
            .init(
                source: record.source,
                target: record.target,
                phase: phase,
                contact: record.contact
            )
        )
    }

    private func appendEnded(_ record: CollisionContactRecord2D) {
        reports.append(
            .init(
                source: record.source,
                target: record.target,
                phase: .ended,
                contact: nil
            )
        )
    }
}

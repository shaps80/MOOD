import Pixl2D

/// Reusable local-space collision probes for ``PlatformerController``.
public struct PlatformerCollisionProbes {
    private static let overlap: Float = 0.05

    private var groundLeft = Segment(start: .zero, end: .init(0, -1))
    private var groundRight = Segment(start: .init(1, 0), end: .init(1, -1))
    private var head = Rect.zero
    private var wallLeft = Rect.zero
    private var wallRight = Rect.zero
    private var groundLeftHit: ColliderRayHit2D?
    private var groundRightHit: ColliderRayHit2D?
    private var headHit = false
    private var wallLeftHit = false
    private var wallRightHit = false

    public init() { }

    /// Updates the probes and returns nearby surface normals for one fixed tick.
    public mutating func update(
        stance: PlatformerStance,
        transform: Transform2D,
        configuration: PlatformerConfiguration.Collision,
        in collisions: CollisionWorld2D
    ) -> PlatformerSurfaces {
        let capsule = configuration.body(for: stance)
        let bounds = worldBounds(of: capsule.bounds, transformedBy: transform)
        let standingBounds = worldBounds(
            of: configuration.standingBody.bounds,
            transformedBy: transform
        )
        let feetOffset = capsule.bounds.minY
            - configuration.standingBody.bounds.minY
        let localFeet = configuration.feet.translated(
            by: .init(0, feetOffset)
        )
        let feet = worldBounds(
            of: localFeet,
            transformedBy: transform
        )
        let groundDistance = feet.height
            + configuration.groundProbeDistance
            + Self.overlap
        let groundY = feet.maxY
        let groundInset = min(feet.width * 0.2, Self.overlap)

        groundLeft = Segment(
            start: .init(feet.minX + groundInset, groundY),
            end: .init(feet.minX + groundInset, groundY - groundDistance)
        )
        groundRight = Segment(
            start: .init(feet.maxX - groundInset, groundY),
            end: .init(feet.maxX - groundInset, groundY - groundDistance)
        )
        groundLeftHit = collisions.rayCast(
            Ray2D(origin: groundLeft.start, direction: .init(0, -1)),
            mask: configuration.surfaceMask,
            maximumDistance: groundDistance
        )
        groundRightHit = collisions.rayCast(
            Ray2D(origin: groundRight.start, direction: .init(0, -1)),
            mask: configuration.surfaceMask,
            maximumDistance: groundDistance
        )

        let headHeight = max(
            configuration.headProbeDistance,
            standingBounds.maxY - bounds.maxY
                + configuration.headProbeDistance
        )
        head = Rect(
            x: bounds.minX,
            y: bounds.maxY - Self.overlap,
            width: bounds.width,
            height: headHeight + Self.overlap
        )
        headHit = overlaps(head, mask: configuration.surfaceMask, in: collisions)

        let wallHeight = bounds.height * configuration.wallProbeHeightScale
        wallLeft = Rect(
            x: bounds.minX - configuration.wallProbeDistance,
            y: bounds.midY - (wallHeight * 0.5),
            width: configuration.wallProbeDistance + Self.overlap,
            height: wallHeight
        )
        wallRight = Rect(
            x: bounds.maxX - Self.overlap,
            y: bounds.midY - (wallHeight * 0.5),
            width: configuration.wallProbeDistance + Self.overlap,
            height: wallHeight
        )
        wallLeftHit = overlaps(
            wallLeft,
            mask: configuration.surfaceMask,
            in: collisions
        )
        wallRightHit = overlaps(
            wallRight,
            mask: configuration.surfaceMask,
            in: collisions
        )

        return PlatformerSurfaces(
            groundNormal: groundNormal(
                minimumY: configuration.minimumGroundNormalY
            ),
            ceilingNormal: headHit ? .init(0, -1) : .zero,
            wallNormal: wallNormal
        )
    }

    /// Prevents a horizontal dash from crossing a surface between fixed ticks.
    public func constrainDash(
        _ displacement: Vec2,
        stance: PlatformerStance,
        transform: Transform2D,
        configuration: PlatformerConfiguration.Collision,
        in collisions: CollisionWorld2D
    ) -> Vec2 {
        guard displacement.x != 0 else { return displacement }

        let bounds = worldBounds(
            of: configuration.body(for: stance).bounds,
            transformedBy: transform
        )
        let direction: Float = displacement.x > 0 ? 1 : -1
        let originX = direction > 0 ? bounds.maxX : bounds.minX
        let radius = bounds.width * 0.5
        let lowerY = min(bounds.midY, bounds.minY + radius)
        let upperY = max(bounds.midY, bounds.maxY - radius)
        let maximumDistance = abs(displacement.x) + Self.overlap
        var allowedDistance = abs(displacement.x)

        includeHorizontalHit(
            from: .init(originX, lowerY),
            direction: direction,
            maximumDistance: maximumDistance,
            mask: configuration.surfaceMask,
            collisions: collisions,
            allowedDistance: &allowedDistance
        )
        includeHorizontalHit(
            from: .init(originX, bounds.midY),
            direction: direction,
            maximumDistance: maximumDistance,
            mask: configuration.surfaceMask,
            collisions: collisions,
            allowedDistance: &allowedDistance
        )
        includeHorizontalHit(
            from: .init(originX, upperY),
            direction: direction,
            maximumDistance: maximumDistance,
            mask: configuration.surfaceMask,
            collisions: collisions,
            allowedDistance: &allowedDistance
        )

        return .init(direction * allowedDistance, displacement.y)
    }

    /// Submits the body and probe geometry used by the latest update.
    public func submitDebug(
        stance: PlatformerStance,
        transform: Transform2D,
        configuration: PlatformerConfiguration.Collision,
        layer: RenderLayer,
        to queue: RenderQueue,
        context: GameContext
    ) {
        queue.submit(
            Shape(configuration.body(for: stance))
                .fill(.clear)
                .stroke(.cyan, width: 1)
                .antialiasing(.smooth),
            transform: transform,
            rendering: .init(layer: layer)
        )

        submit(
            groundLeft,
            hit: groundLeftHit,
            layer: layer,
            to: queue,
            context: context
        )
        submit(
            groundRight,
            hit: groundRightHit,
            layer: layer,
            to: queue,
            context: context
        )
        submit(head, hit: headHit, layer: layer, context: context)
        submit(wallLeft, hit: wallLeftHit, layer: layer, context: context)
        submit(wallRight, hit: wallRightHit, layer: layer, context: context)
    }

    private func includeHorizontalHit(
        from origin: Vec2,
        direction: Float,
        maximumDistance: Float,
        mask: CollisionMask,
        collisions: CollisionWorld2D,
        allowedDistance: inout Float
    ) {
        guard let hit = collisions.rayCast(
            Ray2D(origin: origin, direction: .init(direction, 0)),
            mask: mask,
            maximumDistance: maximumDistance
        ), hit.hit.normal.x * direction < 0
        else { return }

        allowedDistance = min(
            allowedDistance,
            max(0, hit.hit.distance - Self.overlap)
        )
    }

    private func overlaps(
        _ bounds: Rect,
        mask: CollisionMask,
        in collisions: CollisionWorld2D
    ) -> Bool {
        var result = false
        collisions.query(overlapping: bounds, mask: mask) { _ in
            result = true
            return false
        }
        return result
    }

    private func groundNormal(minimumY: Float) -> Vec2 {
        var nearestDistance = Float.infinity
        var result = Vec2.zero
        includeGroundHit(
            groundLeftHit,
            minimumY: minimumY,
            nearestDistance: &nearestDistance,
            result: &result
        )
        includeGroundHit(
            groundRightHit,
            minimumY: minimumY,
            nearestDistance: &nearestDistance,
            result: &result
        )
        return result
    }

    private func includeGroundHit(
        _ hit: ColliderRayHit2D?,
        minimumY: Float,
        nearestDistance: inout Float,
        result: inout Vec2
    ) {
        guard let hit,
              hit.hit.normal.y >= minimumY,
              hit.hit.distance < nearestDistance
        else { return }
        nearestDistance = hit.hit.distance
        result = hit.hit.normal
    }

    private var wallNormal: Vec2 {
        if wallLeftHit, !wallRightHit { return .init(1, 0) }
        if wallRightHit, !wallLeftHit { return .init(-1, 0) }
        return .zero
    }

    private func worldBounds(
        of bounds: Rect,
        transformedBy transform: Transform2D
    ) -> Rect {
        let bottomLeft = point(bounds.origin, transformedBy: transform)
        let bottomRight = point(
            .init(bounds.maxX, bounds.minY),
            transformedBy: transform
        )
        let topLeft = point(
            .init(bounds.minX, bounds.maxY),
            transformedBy: transform
        )
        let topRight = point(
            .init(bounds.maxX, bounds.maxY),
            transformedBy: transform
        )
        let minimum = Vec2(
            min(min(bottomLeft.x, bottomRight.x), min(topLeft.x, topRight.x)),
            min(min(bottomLeft.y, bottomRight.y), min(topLeft.y, topRight.y))
        )
        let maximum = Vec2(
            max(max(bottomLeft.x, bottomRight.x), max(topLeft.x, topRight.x)),
            max(max(bottomLeft.y, bottomRight.y), max(topLeft.y, topRight.y))
        )
        return .init(origin: minimum, size: maximum - minimum)
    }

    private func point(_ point: Vec2, transformedBy transform: Transform2D) -> Vec2 {
        .init(
            (transform.x.x * point.x)
                + (transform.y.x * point.y)
                + transform.translation.x,
            (transform.x.y * point.x)
                + (transform.y.y * point.y)
                + transform.translation.y
        )
    }

    private func submit(
        _ segment: Segment,
        hit: ColliderRayHit2D?,
        layer: RenderLayer,
        to queue: RenderQueue,
        context: GameContext
    ) {
        let color: Color = hit == nil ? .red : .green
        queue.submit(
            Shape(segment).fill(.clear).stroke(color, width: 1),
            transform: .identity,
            rendering: .init(layer: layer)
        )

        guard let hit else { return }
        let point = segment.start + Vec2(0, -hit.hit.distance)
        context.draw(
            .ellipse(in: .init(center: point, size: .init(repeating: 3))),
            style: .fill(color),
            layer: layer
        )
        let normalEnd = point + (hit.hit.normal * 12)
        guard normalEnd != point else { return }
        queue.submit(
            Shape(Segment(start: point, end: normalEnd))
                .fill(.clear)
                .stroke(.yellow, width: 1),
            transform: .identity,
            rendering: .init(layer: layer)
        )
    }

    private func submit(
        _ bounds: Rect,
        hit: Bool,
        layer: RenderLayer,
        context: GameContext
    ) {
        context.draw(
            .rect(bounds),
            style: .stroke(hit ? .green : .red, width: 1),
            layer: layer
        )
    }
}

import PixlConcurrency
import PixlGraphics
import PixlPlatform

/// Value behaviour stored in a typed ``EntityStore``.
public protocol Entity: Sendable {
    init(context: GameContext) throws

    mutating func fixedUpdate(
        entity: EntityID,
        in world: World,
        time: FixedTime,
        lanes: Lanes
    )

    mutating func update(
        entity: EntityID,
        in world: World,
        time: UpdateTime,
        lanes: Lanes
    )

    func render(
        entity: EntityID,
        in world: World,
        output: RenderTarget,
        on pass: RenderPassEncoder,
        time: RenderTime
    ) throws
}

public extension Entity {
    mutating func fixedUpdate(
        entity: EntityID,
        in world: World,
        time: FixedTime,
        lanes: Lanes
    ) {}

    mutating func update(
        entity: EntityID,
        in world: World,
        time: UpdateTime,
        lanes: Lanes
    ) {}

    func render(
        entity: EntityID,
        in world: World,
        output: RenderTarget,
        on pass: RenderPassEncoder,
        time: RenderTime
    ) throws {}
}

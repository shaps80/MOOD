import PixlConcurrency
import PixlPlatform

/// Runtime services available while a game constructs its persistent state.
public final class GameContext {
    private let storedPlatform: (any Platform)?
    private var worlds: ContiguousArray<World> = []

    public var platform: any Platform {
        guard let storedPlatform else {
            preconditionFailure("The testing game context has no platform")
        }
        return storedPlatform
    }

    init(platform: any Platform, worldCapacity: Int = 8) {
        storedPlatform = platform
        worlds.reserveCapacity(worldCapacity)
    }

    private init(worldCapacity: Int) {
        storedPlatform = nil
        worlds.reserveCapacity(worldCapacity)
    }

    static var testing: GameContext { .init(worldCapacity: 0) }

    /// Retains a world and schedules its lifecycle automatically.
    @discardableResult
    public func register(_ world: World) -> World {
        precondition(worlds.count < worlds.capacity, "Game world capacity exceeded")
        worlds.append(world)
        return world
    }

    func fixedUpdate(_ time: FixedTime, lanes: Lanes) {
        for world in worlds {
            world.fixedUpdate(time, lanes: lanes)
        }
    }

    func update(_ time: UpdateTime, lanes: Lanes) {
        for world in worlds {
            world.update(time, lanes: lanes)
        }
    }

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime
    ) throws {
        for world in worlds {
            try world.render(on: platform, output: output, frame: frame, time: time)
        }
    }

    var activeEntityCount: UInt32 {
        worlds.reduce(0) { $0 &+ $1.activeEntityCount }
    }

    var inactiveEntityCount: UInt32 {
        worlds.reduce(0) { $0 &+ $1.inactiveEntityCount }
    }
}

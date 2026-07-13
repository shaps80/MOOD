import PixlConcurrency
import Testing
@testable import Pixl

private struct Counter: Entity {
    var updates = 0
    var despawnsDuringUpdate = false

    mutating func update(
        entity: EntityID,
        in world: World,
        time: UpdateTime,
        lanes: Lanes
    ) {
        updates += 1
        if despawnsDuringUpdate {
            #expect(world.despawn(entity))
        }
    }
}

@Suite("World")
struct WorldTests {
    @Test
    func storageReadsMutatesDespawnsAndReusesSlotsWithoutCompaction() {
        let world = World()
        let counters = world.register(Counter.self, capacity: 2)
        let first = counters.spawn(.init())!
        let second = counters.spawn(.init())!

        _ = counters.update(first) { $0.pointee.updates = 4 }
        #expect(counters.withValue(for: first) { $0.pointee.updates } == 4)
        #expect(world.despawn(first))
        #expect(counters.withValue(for: first) { $0.pointee.updates } == nil)
        #expect(world.activeEntityCount == 1)
        #expect(world.inactiveEntityCount == 1)

        let replacement = counters.spawn(.init())!
        #expect(replacement != first)
        #expect(counters.withValue(for: second) { $0.pointee.updates } == 0)
        #expect(world.activeEntityCount == 2)
        #expect(world.inactiveEntityCount == 0)
    }

    @Test
    func despawningDuringUpdateInvalidatesImmediatelyAndRetiresAfterTheLoop() {
        let world = World()
        let counters = world.register(Counter.self, capacity: 2)
        let entity = counters.spawn(.init(despawnsDuringUpdate: true))!

        world.update(
            .init(frameIndex: 1, deltaSeconds: 1.0 / 60.0, elapsedSeconds: 1.0 / 60.0),
            lanes: .init()
        )

        #expect(counters.withValue(for: entity) { $0.pointee.updates } == nil)
        #expect(world.activeEntityCount == 0)
        #expect(world.inactiveEntityCount == 1)
    }
}

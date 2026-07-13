import XCTest
@testable import Pixl

private struct PerformanceEntity: Entity {
    var value: UInt64

    init(context: GameContext) {
        value = 1
    }
}

final class WorldPerformanceTests: XCTestCase {
    private static let entityCount = 10_000
    private static let passes = 100

    func testSequentialReadPerformance() throws {
        let (store, entities) = try makeFullStore()
        var checksum: UInt64 = 0

        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<Self.passes {
                for index in 0..<Self.entityCount {
                    checksum &+= store.withValue(for: entities[index]) {
                        $0.pointee.value
                    }!
                }
            }
        }

        XCTAssertNotEqual(checksum, 0)
    }

    func testInPlaceUpdatePerformance() throws {
        let (store, entities) = try makeFullStore()

        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<Self.passes {
                for index in 0..<Self.entityCount {
                    store.update(entities[index]) {
                        $0.pointee.value &+= 1
                    }
                }
            }
        }
    }

    func testInsertDespawnChurnPerformance() throws {
        let context = GameContext.testing
        let world = context.register(World())
        let store = world.register(
            PerformanceEntity.self,
            capacity: UInt32(Self.entityCount)
        )
        let entities = UnsafeMutablePointer<EntityID>.allocate(
            capacity: Self.entityCount
        )
        defer { entities.deallocate() }
        var insertSeconds = 0.0
        var insertSamples = 0
        var despawnSeconds = 0.0

        measure(metrics: [XCTClockMetric()]) {
            let insertStart = ContinuousClock.now
            for index in 0..<Self.entityCount {
                entities.advanced(by: index).initialize(
                    to: try! store.spawn()!
                )
            }
            insertSeconds += Self.seconds(ContinuousClock.now - insertStart)
            insertSamples += 1
            let despawnStart = ContinuousClock.now
            for index in 0..<Self.entityCount {
                _ = world.despawn(entities[index])
                entities.advanced(by: index).deinitialize(count: 1)
            }
            despawnSeconds += Self.seconds(ContinuousClock.now - despawnStart)
            world.update(
                .init(frameIndex: 0, deltaSeconds: 0, elapsedSeconds: 0),
                lanes: .init()
            )
        }

        XCTAssertEqual(world.activeEntityCount, 0)
        XCTAssertEqual(world.inactiveEntityCount, UInt32(Self.entityCount))
        let insertNanoseconds = insertSeconds
            / Double(insertSamples * Self.entityCount)
            * 1_000_000_000
        print("World hot insert: \(insertNanoseconds) ns/entity")
        let despawnNanoseconds = despawnSeconds
            / Double(insertSamples * Self.entityCount)
            * 1_000_000_000
        print("World despawn mark: \(despawnNanoseconds) ns/entity")
    }

    private func makeFullStore() throws -> (
        EntityStore<PerformanceEntity>,
        ContiguousArray<EntityID>
    ) {
        let context = GameContext.testing
        let world = context.register(World())
        let store = world.register(
            PerformanceEntity.self,
            capacity: UInt32(Self.entityCount)
        )
        var entities: ContiguousArray<EntityID> = []
        entities.reserveCapacity(Self.entityCount)
        for _ in 0..<Self.entityCount {
            entities.append(
                try store.spawn()!
            )
        }
        return (store, entities)
    }

    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) * 1e-18
    }
}

#if canImport(XCTest)
import XCTest
import PixlBackend

final class ResourcePoolPerformanceTests: XCTestCase {
    private static let elementCount: UInt32 = 150_000

    /// End-to-end cost of allocating the fixed pool, inserting one million
    /// resources, updating each one, and removing each one.
    func testMillionResourceColdStartLifecyclePerformance() {
        measure {
            let pool = ResourcePool<UInt64>(capacity: Self.elementCount)
            let ids = UnsafeMutablePointer<ResourceID>.allocate(
                capacity: Int(Self.elementCount)
            )

            for index in 0..<Self.elementCount {
                ids.advanced(by: Int(index)).initialize(
                    to: pool.insert(UInt64(index))!
                )
            }

            for index in 0..<Self.elementCount {
                _ = pool.update(ids[Int(index)]) { value in
                    value.pointee &+= 1
                }
            }

            for index in 0..<Self.elementCount {
                precondition(pool.remove(ids[Int(index)]))
            }

            precondition(pool.count == 0)
            ids.deinitialize(count: Int(Self.elementCount))
            ids.deallocate()
        }
    }

    /// Hot-path lookup cost against a fully populated, stable pool.
    func testMillionResourceLookupsPerformance() {
        let fixture = makeFixture()
        var checksum: UInt64 = 0
        let options = XCTMeasureOptions()
        options.iterationCount = 100

        measure(metrics: [XCTClockMetric()], options: options) {
            checksum = 0

            for index in 0..<Self.elementCount {
                fixture.pool.withValue(for: fixture.ids[Int(index)]) { value in
                    checksum &+= value.pointee
                }
            }
        }

        XCTAssertNotEqual(checksum, 0)
        destroy(fixture)
    }

    /// Hot-path in-place update cost against a fully populated, stable pool.
    func testMillionResourceUpdatesPerformance() {
        let fixture = makeFixture()
        let options = XCTMeasureOptions()
        options.iterationCount = 100

        measure(metrics: [XCTClockMetric()], options: options) {
            for index in 0..<Self.elementCount {
                fixture.pool.update(fixture.ids[Int(index)]) { value in
                    value.pointee &+= 1
                }
            }
        }

        fixture.pool.withValue(for: fixture.ids[0]) { value in
            XCTAssertGreaterThan(value.pointee, 0)
        }
        destroy(fixture)
    }

    /// Steady-state free-list cost: remove every resource, then reuse every slot.
    func testMillionResourceChurnPerformance() {
        let fixture = makeFixture()

        measure {
            for index in 0..<Self.elementCount {
                precondition(fixture.pool.remove(fixture.ids[Int(index)]))
            }

            for index in 0..<Self.elementCount {
                fixture.ids[Int(index)] = fixture.pool.insert(UInt64(index))!
            }
        }

        XCTAssertEqual(fixture.pool.count, Self.elementCount)
        destroy(fixture)
    }

    private typealias Fixture = (
        pool: ResourcePool<UInt64>,
        ids: UnsafeMutablePointer<ResourceID>
    )

    private func makeFixture() -> Fixture {
        let pool = ResourcePool<UInt64>(capacity: Self.elementCount)
        let ids = UnsafeMutablePointer<ResourceID>.allocate(
            capacity: Int(Self.elementCount)
        )

        for index in 0..<Self.elementCount {
            ids.advanced(by: Int(index)).initialize(
                to: pool.insert(UInt64(index))!
            )
        }

        return (pool, ids)
    }

    private func destroy(_ fixture: Fixture) {
        fixture.ids.deinitialize(count: Int(Self.elementCount))
        fixture.ids.deallocate()
    }
}

#endif

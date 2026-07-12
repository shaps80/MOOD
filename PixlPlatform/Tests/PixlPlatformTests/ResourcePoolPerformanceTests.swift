#if !os(WASI)
import XCTest
@testable import PixlPlatform

final class ResourcePoolPerformanceTests: XCTestCase {
    func testPerformance() {
        let pool = ResourcePool<UInt64>(capacity: 150_000)
        let ids = (0..<150_000).map { pool.insert(UInt64($0))! }

        measure {
            var checksum: UInt64 = 0
            for id in ids {
                pool.withValue(for: id) { checksum &+= $0.pointee }
            }
            XCTAssertNotEqual(checksum, 0)
        }
    }
}
#endif

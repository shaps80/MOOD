#if canImport(XCTest)
import XCTest
import PixlPlatformTestSupport

final class ResourcePoolPerformanceTests: XCTestCase {
    func testPerformance() {
        ResourcePoolSuite.runBenchmarks().printResults()
    }
}
#endif

#if canImport(XCTest)
import XCTest
import PixlBackendTestSupport

final class ResourcePoolTests: XCTestCase {
    func testCorrectness() throws {
        try ResourcePoolSuite.runChecks()
    }

    func testPerformance() {
        ResourcePoolSuite.runBenchmarks().printResults()
    }
}
#endif

import Testing
import PixlPlatformTestSupport

@Suite("ResourcePool")
struct ResourcePoolTests {
    @Test
    func correctness() throws {
        try ResourcePoolSuite.runChecks()
    }
}

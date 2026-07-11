import Swift
import PixlPlatformTestSupport

@main
struct PixlPlatformTestRunner {
    static func main() throws {
        try ResourcePoolSuite.runChecks()
        print("ResourcePool checks passed.")
        print("")

        ResourcePoolSuite.runBenchmarks().printResults()
    }
}


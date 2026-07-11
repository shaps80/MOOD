import Swift
import PixlBackendTestSupport

@main
struct PixlBackendTestRunner {
    static func main() throws {
        try ResourcePoolSuite.runChecks()
        print("ResourcePool checks passed.")
        print("")

        ResourcePoolSuite.runBenchmarks().printResults()
    }
}


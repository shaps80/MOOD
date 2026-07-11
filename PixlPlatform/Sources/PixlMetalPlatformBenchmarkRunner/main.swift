import PixlMetalPlatformBenchmarkSupport

do {
    try MetalResourcePoolRuntimeScenario.runChecks()
    MetalResourcePoolRuntimeScenario.runBenchmarks().printResults()
} catch {
    fatalError("Metal ResourcePool benchmark failed: \(error)")
}

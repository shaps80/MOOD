import PixlMemory
import Swift

@main
enum Benchmarks {
    static func main() {
        #if DEBUG
        fatalError("PixlMemory benchmarks must run in release configuration")
        #else
        var results = ArenaBenchmarks.run()
        let arena = try! Arena(
            StoragePersistent.self,
            layouts: StorageLayout.self,
            logging: .disabled
        )
        let scope = arena.acquire(StorageLayout.self)
        results += IndexedBufferBenchmarks.run(scope: scope)
        results += RawBufferBenchmarks.run(scope: scope)
        results += DensePoolBenchmarks.run(scope: scope)
        scope.release()
        results += FrameBenchmarks.run()
        results += ParticleBenchmarks.run()
        print(BenchmarkReport(results: results))
        #endif
    }
}

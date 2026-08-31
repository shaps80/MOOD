import PixlMemory
import Swift

enum ArenaBenchmarks {
    static func run() -> [BenchmarkResult] {
        let constructionCount = 10_000
        let construction = BenchmarkRunner.measure(
            "Arena construction",
            operation: "arena",
            operationsPerSample: constructionCount,
            prepare: {},
            body: {
                var checksum: UInt64 = 0
                for _ in 0..<constructionCount {
                    let arena = try! Arena(
                        TinyPersistent.self,
                        layouts: TinyLayout.self,
                        logging: .disabled
                    )
                    checksum &+= arena.reserved.rawValue
                }
                return checksum
            }
        )

        let arena = try! Arena(
            TinyPersistent.self,
            layouts: TinyLayout.self,
            logging: .disabled
        )
        let acquireCount = 100_000
        let acquireRelease = BenchmarkRunner.measure(
            "Scope acquire/release",
            operation: "scope",
            operationsPerSample: acquireCount,
            prepare: {},
            body: {
                var checksum: UInt64 = 0
                for _ in 0..<acquireCount {
                    let scope = arena.acquire(TinyLayout.self)
                    checksum &+= scope.statistics.reserved.rawValue
                    scope.release()
                }
                return checksum
            }
        )
        return [construction, acquireRelease]
    }
}

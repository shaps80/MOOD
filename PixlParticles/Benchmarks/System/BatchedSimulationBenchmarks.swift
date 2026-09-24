import Foundation
import Swift

@main
struct BatchedSimulationBenchmarks {
    static func main() {
        Thread.current.qualityOfService = .userInteractive
        let mode = SimulationWorkers.Mode(rawValue: CommandLine.arguments.dropFirst().first ?? "serial")!
        let multiplier = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2])! : 4
        let configuration = SimulationWorkers(mode: mode, batchesPerWorker: multiplier)
        let pool = mode == .serial ? nil : SpinningJobPool(workerCount: configuration.count,
                                                         batchesPerWorker: multiplier)
        print("mode=\(mode.rawValue) workers=\(configuration.count) batches_per_worker=\(multiplier)")
        for count in [1_000_000, 2_000_000] {
            let system = System(seed: 0, spawnRate: Float(count) / 2,
                lifetime: 2, spawnRegion: .sphere(radius: 100, domain: .surface),
                duration: .zero, storesRewindState: false)
            system.executor = pool
            for _ in 0..<150 { system.update(by: 1.0 / 60.0) }
            var times: [Double] = []
            times.reserveCapacity(301)
            for _ in 0..<301 {
                let start = ContinuousClock.now
                system.update(by: 1.0 / 60.0)
                let c = start.duration(to: .now).components
                times.append(Double(c.seconds) * 1_000 + Double(c.attoseconds) * 1e-15)
            }
            var checksum: UInt64 = 0
            for p in system.particleSnapshot {
                checksum &+= p.id
                for v in [p.position, p.previousPosition, p.velocity] {
                    checksum &+= UInt64(v.x.bitPattern)
                    checksum &+= UInt64(v.y.bitPattern)
                    checksum &+= UInt64(v.z.bitPattern)
                }
            }
            times.sort()
            print("particles=\(count) median_ms=\(times[150]) p95_ms=\(times[285]) checksum=\(checksum)")
        }
    }
}

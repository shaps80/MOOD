@_spi(EditorDiagnostics) import PixlParticles
import Foundation
import Swift

@main
struct LiveTickBenchmarks {
    private static let particleCount = 1_000_000
    private static let warmupCount = 10
    private static let sampleCount = 51
    private static let cacheScrubByteCount = 128 * 1_024 * 1_024

    static func main() {
        benchmark(scrubsCache: false)
        benchmark(scrubsCache: true)
        benchmarkWallClockCadence()
    }

    @_optimize(none)
    private static func benchmarkWallClockCadence() {
        let system = PixlParticles.System(
            seed: 0x0123456789ABCDEF,
            particleCount: particleCount,
            spawnRegion: .point(.zero),
            duration: .seconds(60)
        )
        var samples: [Double] = []
        samples.reserveCapacity(sampleCount)

        _ = system.diagnosticSample(at: .now)

        while samples.count < warmupCount + sampleCount {
            Thread.sleep(forTimeInterval: 1.0 / 30.0)
            if let duration = system.diagnosticSample(
                at: .now
            ).fixedUpdateTime {
                samples.append(duration)
            }
        }

        samples.removeFirst(warmupCount)
        let average = samples.reduce(0, +) / Double(samples.count) * 1_000
        samples.sort()

        let median = samples[sampleCount / 2] * 1_000
        let p95 = samples[Int(Double(sampleCount - 1) * 0.95)] * 1_000
        print(
            "Real 30 Hz cadence: average \(average), median \(median), "
                + "p95 \(p95) ms/tick"
        )
    }

    @_optimize(none)
    private static func benchmark(scrubsCache: Bool) {
        let system = PixlParticles.System(
            seed: 0x0123456789ABCDEF,
            particleCount: particleCount,
            spawnRegion: .point(.zero),
            duration: .seconds(60)
        )
        var cache = scrubsCache
            ? [UInt64](
                repeating: 0,
                count: cacheScrubByteCount / MemoryLayout<UInt64>.stride
            )
            : []
        var instant = ContinuousClock.now
        var checksum: UInt64 = 0
        var samples: [Double] = []
        samples.reserveCapacity(sampleCount)

        _ = system.diagnosticSample(at: instant)

        while samples.count < warmupCount + sampleCount {
            if scrubsCache {
                checksum &+= scrubCache(&cache)
            }
            instant = instant.advanced(by: .seconds(1.0 / 30.0))
            let result = system.diagnosticSample(at: instant)
            checksum &+= result.sample.tick
            if let duration = result.fixedUpdateTime {
                samples.append(duration)
            }
        }

        samples.removeFirst(warmupCount)
        let average = samples.reduce(0, +) / Double(samples.count) * 1_000
        samples.sort()

        let median = samples[sampleCount / 2] * 1_000
        let p95 = samples[Int(Double(sampleCount - 1) * 0.95)] * 1_000
        let name = scrubsCache ? "Cache-evicted" : "Scheduled hot-cache"
        print(
            "\(name): average \(average), median \(median), p95 \(p95) "
                + "ms/tick [\(checksum)]"
        )
    }

    @inline(never)
    private static func scrubCache(_ storage: inout [UInt64]) -> UInt64 {
        var checksum: UInt64 = 0

        storage.withUnsafeMutableBufferPointer { buffer in
            var index = 0
            while index < buffer.count {
                buffer[index] &+= UInt64(index) &+ 1
                checksum &+= buffer[index]
                index += 8
            }
        }

        return checksum
    }
}

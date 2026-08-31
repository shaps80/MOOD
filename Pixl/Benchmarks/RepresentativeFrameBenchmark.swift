import PixlFoundation
import Swift

struct RepresentativeFrameBenchmark {
    private static let warmupFrameCount = 10
    private static let measuredFrameCount = 51

    func run() -> BenchmarkReport {
        let residentBefore = MemoryReport.residentBytes()
        let render = RenderWorkload()
        let collision = CollisionWorkload()
        let residentAfterWorkload = MemoryReport.residentBytes()

        var total: [Double] = []
        var collisionUpdate: [Double] = []
        var collisionAdvance: [Double] = []
        var collisionQuery: [Double] = []
        var collisionRayCast: [Double] = []
        var submission: [Double] = []
        var lowering: [Double] = []
        var culling: [Double] = []
        var layerBinning: [Double] = []
        var ordering: [Double] = []
        var batching: [Double] = []
        var instances: [Double] = []
        var latest: FrameResult?

        total.reserveCapacity(Self.measuredFrameCount)
        collisionUpdate.reserveCapacity(Self.measuredFrameCount)
        collisionAdvance.reserveCapacity(Self.measuredFrameCount)
        collisionQuery.reserveCapacity(Self.measuredFrameCount)
        collisionRayCast.reserveCapacity(Self.measuredFrameCount)
        submission.reserveCapacity(Self.measuredFrameCount)
        lowering.reserveCapacity(Self.measuredFrameCount)
        culling.reserveCapacity(Self.measuredFrameCount)
        layerBinning.reserveCapacity(Self.measuredFrameCount)
        ordering.reserveCapacity(Self.measuredFrameCount)
        batching.reserveCapacity(Self.measuredFrameCount)
        instances.reserveCapacity(Self.measuredFrameCount)

        for _ in 0..<Self.warmupFrameCount {
            _ = frame(render: render, collision: collision)
        }
        let residentAfterWarmup = MemoryReport.residentBytes()

        for _ in 0..<Self.measuredFrameCount {
            let result = frame(render: render, collision: collision)
            latest = result
            total.append(result.totalSeconds)
            collisionUpdate.append(result.collisionUpdateSeconds)
            collisionAdvance.append(result.collisionAdvanceSeconds)
            collisionQuery.append(result.collisionQuerySeconds)
            collisionRayCast.append(result.collisionRayCastSeconds)
            submission.append(result.submissionSeconds)
            lowering.append(result.renderMetrics.loweringSeconds)
            culling.append(result.renderMetrics.cullingSeconds)
            layerBinning.append(result.renderMetrics.layerBinningSeconds)
            ordering.append(result.renderMetrics.orderingSeconds)
            batching.append(result.renderMetrics.batchingSeconds)
            instances.append(result.renderMetrics.instancesSeconds)
        }

        let final = latest!
        let renderChecksum = render.correctnessChecksum()
        let checksum = mix(
            mix(final.collisionChecksum, final.rayChecksum),
            renderChecksum
        )
        let residentAfterMeasurement = MemoryReport.residentBytes()
        return BenchmarkReport(
            warmupFrameCount: Self.warmupFrameCount,
            measuredFrameCount: Self.measuredFrameCount,
            submissionCount: RenderWorkload.submissionCount,
            visibleCount: final.visibleCount,
            colliderCount: CollisionWorkload.colliderCount,
            collisionReportCount: final.collisionReportCount,
            queryHitCount: final.queryHitCount,
            rayHitCount: final.rayHitCount,
            checksum: checksum,
            memory: MemoryReport(
                before: residentBefore,
                afterWorkload: residentAfterWorkload,
                afterWarmup: residentAfterWarmup,
                afterMeasurement: residentAfterMeasurement,
                peak: MemoryReport.peakResidentBytes()
            ),
            measurements: [
                measurement("Total CPU frame", total),
                measurement("Collision updates", collisionUpdate),
                measurement("Collision advance", collisionAdvance),
                measurement("Collision overlap queries", collisionQuery),
                measurement("Collision ray casts", collisionRayCast),
                measurement("Render submission", submission),
                measurement("Render lowering", lowering),
                measurement("Render culling", culling),
                measurement("Render layer binning", layerBinning),
                measurement("Render ordering", ordering),
                measurement("Render batching", batching),
                measurement("Render instances", instances),
            ]
        )
    }

    private func frame(
        render: RenderWorkload,
        collision: CollisionWorkload
    ) -> FrameResult {
        let frameStart = ContinuousClock.now

        let updateStart = ContinuousClock.now
        collision.update()
        let updateSeconds = seconds(since: updateStart)

        let advanceStart = ContinuousClock.now
        let collisionResult = collision.advance()
        let advanceSeconds = seconds(since: advanceStart)

        let queryStart = ContinuousClock.now
        let queryHitCount = collision.query()
        let querySeconds = seconds(since: queryStart)

        let rayStart = ContinuousClock.now
        let rayResult = collision.rayCast()
        let raySeconds = seconds(since: rayStart)

        let submissionStart = ContinuousClock.now
        render.submit()
        let submissionSeconds = seconds(since: submissionStart)

        let execution = render.execute()
        let totalSeconds = seconds(since: frameStart)
        return FrameResult(
            totalSeconds: totalSeconds,
            collisionUpdateSeconds: updateSeconds,
            collisionAdvanceSeconds: advanceSeconds,
            collisionQuerySeconds: querySeconds,
            collisionRayCastSeconds: raySeconds,
            submissionSeconds: submissionSeconds,
            renderMetrics: execution.metrics,
            visibleCount: execution.visibleCount,
            collisionReportCount: collisionResult.reportCount,
            queryHitCount: queryHitCount,
            rayHitCount: rayResult.hitCount,
            collisionChecksum: collisionResult.checksum,
            rayChecksum: rayResult.checksum
        )
    }

    private func measurement(
        _ name: String,
        _ values: [Double]
    ) -> BenchmarkReport.Measurement {
        .init(name: name, statistics: BenchmarkStatistics(values))
    }

    private func seconds(since start: ContinuousClock.Instant) -> Double {
        let value = (ContinuousClock.now - start).components
        return Double(value.seconds) + Double(value.attoseconds) * 1e-18
    }
}

private struct FrameResult {
    let totalSeconds: Double
    let collisionUpdateSeconds: Double
    let collisionAdvanceSeconds: Double
    let collisionQuerySeconds: Double
    let collisionRayCastSeconds: Double
    let submissionSeconds: Double
    let renderMetrics: RenderQueue.Metrics
    let visibleCount: Int
    let collisionReportCount: Int
    let queryHitCount: Int
    let rayHitCount: Int
    let collisionChecksum: UInt64
    let rayChecksum: UInt64
}

private func mix(_ checksum: UInt64, _ value: UInt64) -> UInt64 {
    (checksum ^ value) &* 0x0000_0100_0000_01B3
}

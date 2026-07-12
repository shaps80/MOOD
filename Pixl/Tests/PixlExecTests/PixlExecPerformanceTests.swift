import Foundation
import XCTest
@testable import PixlExec

private final class BenchmarkContext: @unchecked Sendable {
    let values: UnsafeMutableBufferPointer<UInt64>
    let partialSums: UnsafeMutableBufferPointer<UInt64>
    let cursor: WorkCursor
    let dynamic: Bool
    let iterations: Int
    var checksum: UInt64 = 0

    init(count: Int, laneCount: Int, dynamic: Bool, iterations: Int) {
        values = .allocate(capacity: count)
        values.initialize(repeating: 0)
        partialSums = .allocate(capacity: laneCount)
        partialSums.initialize(repeating: 0)
        cursor = WorkCursor(
            count: count,
            laneCount: laneCount,
            chunksPerLane: 8,
            alignment: 8
        )
        self.dynamic = dynamic
        self.iterations = iterations
    }

    deinit {
        values.deinitialize()
        values.deallocate()
        partialSums.deinitialize()
        partialSums.deallocate()
    }
}

private enum BenchmarkProgram: LaneProgram {
    static func execute(_ context: BenchmarkContext, on lane: Lane) {
        for iteration in 0..<context.iterations {
            var partial: UInt64 = 0

            if context.dynamic {
                while let range = lane.claim(from: context.cursor) {
                    partial &+= process(range, iteration: iteration, context: context)
                }
            } else {
                partial = process(
                    lane.range(count: context.values.count),
                    iteration: iteration,
                    context: context
                )
            }

            context.partialSums[lane.index] = partial
            lane.synchronize()

            if lane.isLeader {
                for index in 0..<lane.count {
                    context.checksum &+= context.partialSums[index]
                }
                context.cursor.reset()
            }
            lane.synchronize()
        }
    }

    @inline(__always)
    private static func process(
        _ range: Range<Int>,
        iteration: Int,
        context: BenchmarkContext
    ) -> UInt64 {
        var partial: UInt64 = 0
        for index in range {
            let value = UInt64(index) &* 31 &+ UInt64(iteration)
            context.values[index] = value
            partial &+= value
        }
        return partial
    }
}

final class PixlExecPerformanceTests: XCTestCase {
    private let elementCount = 4_000_000
    private let iterations = 20

    func testSingleLanePerformance() {
        measureExecution(laneCount: 1, dynamic: false)
    }

    func testStaticLanePerformance() {
        measureExecution(laneCount: performanceLaneCount, dynamic: false)
    }

    func testDynamicLanePerformance() {
        measureExecution(laneCount: performanceLaneCount, dynamic: true)
    }

    private var performanceLaneCount: Int {
        min(10, max(1, ProcessInfo.processInfo.activeProcessorCount))
    }

    private func measureExecution(laneCount: Int, dynamic: Bool) {
        let group = ExecutionGroup<BenchmarkProgram>(
            topology: nil,
            settings: .init(laneCount: .fixed(laneCount))
        )
        let context = BenchmarkContext(
            count: elementCount,
            laneCount: laneCount,
            dynamic: dynamic,
            iterations: iterations
        )

        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            group.run(context)
        }

        XCTAssertNotEqual(context.checksum, 0)
    }
}

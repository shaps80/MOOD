import Foundation
import XCTest
@testable import PixlConcurrency

private final class BenchmarkContext: @unchecked Sendable {
    enum Kernel {
        case scalar
        case simd8
    }

    let values: UnsafeMutableBufferPointer<UInt64>
    let partialSums: UnsafeMutableBufferPointer<UInt64>
    let cursor: WorkCursor
    let dynamic: Bool
    let kernel: Kernel
    let iterations: Int
    var checksum: UInt64 = 0

    init(
        count: Int,
        laneCount: Int,
        dynamic: Bool,
        kernel: Kernel,
        iterations: Int
    ) {
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
        self.kernel = kernel
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
                    lane.partition(count: context.values.count),
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
        switch context.kernel {
        case .scalar:
            return processScalar(range, iteration: iteration, context: context)
        case .simd8:
            return processSIMD8(range, iteration: iteration, context: context)
        }
    }

    @inline(__always)
    private static func processScalar(
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

    @inline(__always)
    private static func processSIMD8(
        _ range: Range<Int>,
        iteration: Int,
        context: BenchmarkContext
    ) -> UInt64 {
        let width = 8
        var index = range.lowerBound
        var partial: UInt64 = 0

        while index < range.upperBound && index & (width - 1) != 0 {
            let value = UInt64(index) &* 31 &+ UInt64(iteration)
            context.values[index] = value
            partial &+= value
            index += 1
        }

        let offsets = SIMD8<UInt64>(0, 1, 2, 3, 4, 5, 6, 7)
        let multiplier = SIMD8<UInt64>(repeating: 31)
        let iterationVector = SIMD8<UInt64>(repeating: UInt64(iteration))

        while index + width <= range.upperBound {
            let indices = SIMD8<UInt64>(repeating: UInt64(index)) &+ offsets
            let vector = indices &* multiplier &+ iterationVector
            context.values.baseAddress!.advanced(by: index).withMemoryRebound(
                to: SIMD8<UInt64>.self,
                capacity: 1
            ) { $0.pointee = vector }
            partial &+= vector[0]
            partial &+= vector[1]
            partial &+= vector[2]
            partial &+= vector[3]
            partial &+= vector[4]
            partial &+= vector[5]
            partial &+= vector[6]
            partial &+= vector[7]
            index += width
        }

        while index < range.upperBound {
            let value = UInt64(index) &* 31 &+ UInt64(iteration)
            context.values[index] = value
            partial &+= value
            index += 1
        }

        return partial
    }
}

final class PixlConcurrencyPerformanceTests: XCTestCase {
    private let elementCount = 4_000_000
    private let iterations = 20

    func testLifecyclePerformance() {
        var checksum: UInt64 = 0

        measure(metrics: metrics) {
            let group = ExecutionGroup<BenchmarkProgram>(
                topology: nil,
                settings: .init(laneCount: .fixed(performanceLaneCount))
            )
            let context = BenchmarkContext(
                count: elementCount,
                laneCount: performanceLaneCount,
                dynamic: true,
                kernel: .scalar,
                iterations: iterations
            )
            group.run(context)
            checksum &+= context.checksum
        }

        XCTAssertNotEqual(checksum, 0)
    }

    func testHotSingleLaneScalarPerformance() {
        measureExecution(laneCount: 1, dynamic: false, kernel: .scalar)
    }

    func testHotStaticScalarPerformance() {
        measureExecution(
            laneCount: performanceLaneCount,
            dynamic: false,
            kernel: .scalar
        )
    }

    func testHotDynamicScalarPerformance() {
        measureExecution(
            laneCount: performanceLaneCount,
            dynamic: true,
            kernel: .scalar
        )
    }

    func testHotSingleLaneSIMDPerformance() {
        measureExecution(laneCount: 1, dynamic: false, kernel: .simd8)
    }

    func testHotDynamicSIMDPerformance() {
        measureExecution(
            laneCount: performanceLaneCount,
            dynamic: true,
            kernel: .simd8
        )
    }

    private var performanceLaneCount: Int {
        min(10, max(1, ProcessInfo.processInfo.activeProcessorCount))
    }

    private var metrics: [any XCTMetric] {
        [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]
    }

    private func measureExecution(
        laneCount: Int,
        dynamic: Bool,
        kernel: BenchmarkContext.Kernel
    ) {
        let group = ExecutionGroup<BenchmarkProgram>(
            topology: nil,
            settings: .init(laneCount: .fixed(laneCount))
        )
        let context = BenchmarkContext(
            count: elementCount,
            laneCount: laneCount,
            dynamic: dynamic,
            kernel: kernel,
            iterations: iterations
        )

        measure(metrics: metrics) {
            group.run(context)
        }

        XCTAssertNotEqual(context.checksum, 0)
    }
}

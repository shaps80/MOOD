import Foundation
import PixlPlatform
import XCTest
@testable import PixlExec

private final class CoverageContext: @unchecked Sendable {
    let values: UnsafeMutableBufferPointer<Int>
    let cursor: WorkCursor
    let dynamic: Bool

    init(count: Int, laneCount: Int, dynamic: Bool) {
        values = .allocate(capacity: count)
        values.initialize(repeating: 0)
        cursor = WorkCursor(
            count: count,
            laneCount: laneCount,
            chunksPerLane: 8
        )
        self.dynamic = dynamic
    }

    deinit {
        values.deinitialize()
        values.deallocate()
    }
}

private enum CoverageProgram: LaneProgram {
    static func execute(_ context: CoverageContext, on lane: Lane) {
        if context.dynamic {
            while let range = lane.claim(from: context.cursor) {
                for index in range { context.values[index] += 1 }
            }
        } else {
            for index in lane.range(count: context.values.count) {
                context.values[index] += 1
            }
        }
        lane.synchronize()
        if lane.isLeader { context.cursor.reset() }
        lane.synchronize()
    }
}

private final class PhaseContext: @unchecked Sendable {
    let values: UnsafeMutableBufferPointer<Int>

    init(laneCount: Int) {
        values = .allocate(capacity: laneCount)
        values.initialize(repeating: 0)
    }

    deinit {
        values.deinitialize()
        values.deallocate()
    }
}

private enum PhaseProgram: LaneProgram {
    static func execute(_ context: PhaseContext, on lane: Lane) {
        for phase in 1...32 {
            context.values[lane.index] = phase
            lane.synchronize()
            if lane.isLeader {
                for index in 0..<lane.count {
                    precondition(context.values[index] == phase)
                }
            }
            lane.synchronize()
        }
    }
}

final class PixlExecTests: XCTestCase {
    func testStaticRangesCoverEveryElementExactlyOnce() {
        verifyCoverage(dynamic: false, count: 10_003, laneCount: 7)
    }

    func testDynamicChunksCoverEveryElementExactlyOnce() {
        verifyCoverage(dynamic: true, count: 10_003, laneCount: 7)
    }

    func testSingleLaneExecution() {
        verifyCoverage(dynamic: true, count: 1_003, laneCount: 1)
    }

    func testMoreLanesThanElements() {
        verifyCoverage(dynamic: true, count: 3, laneCount: 8)
    }

    func testRepeatedRunsReusePersistentWorkers() {
        let group = ExecutionGroup<CoverageProgram>(
            topology: nil,
            settings: .init(laneCount: .fixed(4))
        )

        for _ in 0..<100 {
            let context = CoverageContext(count: 1_003, laneCount: 4, dynamic: true)
            group.run(context)
            XCTAssertTrue(context.values.allSatisfy { $0 == 1 })
        }
    }

    func testRepeatedPhaseBarriers() {
        let laneCount = 8
        let group = ExecutionGroup<PhaseProgram>(
            topology: nil,
            settings: .init(laneCount: .fixed(laneCount))
        )
        let context = PhaseContext(laneCount: laneCount)

        group.run(context)

        XCTAssertTrue(context.values.allSatisfy { $0 == 32 })
    }

    func testAutomaticSettingsPreferPerformanceProcessors() {
        let topology = ExecutionTopology(
            availableProcessorCount: 14,
            performanceProcessorCount: 10
        )
        let group = ExecutionGroup<CoverageProgram>(topology: topology)

        XCTAssertEqual(group.laneCount, 10)
    }

    func testExplicitSettingsRemainAuthoritative() {
        let topology = ExecutionTopology(
            availableProcessorCount: 14,
            performanceProcessorCount: 10
        )
        let group = ExecutionGroup<CoverageProgram>(
            topology: topology,
            settings: .init(laneCount: .fixed(1))
        )

        XCTAssertEqual(group.laneCount, 1)
    }

    private func verifyCoverage(dynamic: Bool, count: Int, laneCount: Int) {
        let group = ExecutionGroup<CoverageProgram>(
            topology: nil,
            settings: .init(laneCount: .fixed(laneCount))
        )
        let context = CoverageContext(
            count: count,
            laneCount: laneCount,
            dynamic: dynamic
        )

        group.run(context)

        XCTAssertTrue(context.values.allSatisfy { $0 == 1 })
    }
}

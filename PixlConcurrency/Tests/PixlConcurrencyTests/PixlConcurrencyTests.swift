import Testing
@testable import PixlConcurrency

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
            for index in lane.partition(count: context.values.count) {
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

@Suite("PixlConcurrency")
struct PixlConcurrencyTests {
    @Test
    func staticRangesCoverEveryElementExactlyOnce() {
        verifyCoverage(dynamic: false, count: 10_003, laneCount: 7)
    }

    @Test
    func dynamicChunksCoverEveryElementExactlyOnce() {
        verifyCoverage(dynamic: true, count: 10_003, laneCount: 7)
    }

    @Test
    func singleLaneExecution() {
        verifyCoverage(dynamic: true, count: 1_003, laneCount: 1)
    }

    @Test
    func moreLanesThanElements() {
        verifyCoverage(dynamic: true, count: 3, laneCount: 8)
    }

    @Test
    func repeatedRunsReusePersistentWorkers() {
        let group = ExecutionGroup<CoverageProgram>(
            topology: nil,
            settings: .init(laneCount: .fixed(4))
        )
        let context = CoverageContext(count: 1_003, laneCount: group.laneCount, dynamic: true)

        for _ in 0..<100 {
            group.run(context)
        }

        #expect(context.values.allSatisfy { $0 == 100 })
    }

    @Test
    func executionGroupReleasesPersistentWorkers() {
        weak var releasedGroup: ExecutionGroup<CoverageProgram>?

        do {
            let group = ExecutionGroup<CoverageProgram>(
                topology: nil,
                settings: .init(laneCount: .fixed(4))
            )
            releasedGroup = group
        }

        #expect(releasedGroup == nil)
    }

    @Test
    func repeatedPhaseBarriers() {
        let laneCount = 8
        let group = ExecutionGroup<PhaseProgram>(
            topology: nil,
            settings: .init(laneCount: .fixed(laneCount))
        )
        let context = PhaseContext(laneCount: group.laneCount)

        group.run(context)

        #expect(context.values.prefix(group.laneCount).allSatisfy { $0 == 32 })
    }

    @Test
    func automaticSettingsPreferPerformanceProcessors() {
        let topology = ExecutionTopology(
            availableProcessorCount: 14,
            performanceProcessorCount: 10
        )
        let group = ExecutionGroup<CoverageProgram>(topology: topology)

#if os(WASI)
        #expect(group.laneCount == 1)
#else
        #expect(group.laneCount == 10)
#endif
    }

    @Test
    func explicitSettingsRemainAuthoritative() {
        let topology = ExecutionTopology(
            availableProcessorCount: 14,
            performanceProcessorCount: 10
        )
        let group = ExecutionGroup<CoverageProgram>(
            topology: topology,
            settings: .init(laneCount: .fixed(1))
        )

        #expect(group.laneCount == 1)
    }

    @Test
    func emptyCursorHasNoWork() {
        let cursor = WorkCursor(count: 0, chunkSize: 8)

        #expect(cursor.claim() == nil)
        cursor.reset()
        #expect(cursor.claim() == nil)
    }

    @Test
    func cursorHandlesNonDivisibleTail() {
        let cursor = WorkCursor(count: 10, chunkSize: 4)

        #expect(cursor.claim() == 0..<4)
        #expect(cursor.claim() == 4..<8)
        #expect(cursor.claim() == 8..<10)
        #expect(cursor.claim() == nil)
    }

    @Test
    func cursorHonorsChunkAlignment() {
        let cursor = WorkCursor(
            count: 1_003,
            laneCount: 7,
            chunksPerLane: 3,
            alignment: 8
        )

        #expect(cursor.chunkSize % 8 == 0)
        while let range = cursor.claim() {
            #expect(range.lowerBound % 8 == 0)
            #expect(range.upperBound <= cursor.count)
        }
    }

    @Test
    func cursorArithmeticAtIntegerBoundary() {
        let cursor = WorkCursor(count: .max, chunkSize: .max - 1)

        #expect(cursor.claim() == 0..<(Int.max - 1))
        #expect(cursor.claim() == (Int.max - 1)..<Int.max)
        #expect(cursor.claim() == nil)
    }

    private func verifyCoverage(dynamic: Bool, count: Int, laneCount: Int) {
        let group = ExecutionGroup<CoverageProgram>(
            topology: nil,
            settings: .init(laneCount: .fixed(laneCount))
        )
        let context = CoverageContext(
            count: count,
            laneCount: group.laneCount,
            dynamic: dynamic
        )

        group.run(context)

        #expect(context.values.allSatisfy { $0 == 1 })
    }
}

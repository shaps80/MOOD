import Foundation
import PixlConcurrency
import Testing
@testable import Pixl

private final class LifecycleRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var fixedLanes: [Int] = []
    private var updateLanes: [Int] = []

    func recordFixed(on lane: Lane) {
        lock.lock()
        fixedLanes.append(lane.index)
        lock.unlock()
    }

    func recordUpdate(on lane: Lane) {
        lock.lock()
        updateLanes.append(lane.index)
        lock.unlock()
    }

    func snapshot() -> (fixed: [Int], update: [Int]) {
        lock.lock()
        defer { lock.unlock() }
        return (fixedLanes, updateLanes)
    }
}

private struct LaneRecordingGame: Game {
    let recorder: LifecycleRecorder

    static var gameSettings: GameSettings {
        .init(
            title: "Test",
            preferredFps: 60,
            resolution: .init(width: 1, height: 1)
        )
    }

    init(platform: any Platform) throws {
        recorder = .init()
    }

    init(recorder: LifecycleRecorder) {
        self.recorder = recorder
    }

    func fixedUpdate(_ time: FixedTime, lane: Lane) {
        recorder.recordFixed(on: lane)
    }

    func update(_ time: UpdateTime, lane: Lane) {
        recorder.recordUpdate(on: lane)
    }

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime
    ) throws {}
}

@Suite("Game runtime")
struct GameRuntimeTests {
    @Test
    func lifecycleRunsOncePerLane() {
        let recorder = LifecycleRecorder()
        let runtime = GameRuntime(
            game: LaneRecordingGame(recorder: recorder),
            executionSettings: .init(laneCount: .fixed(3))
        )

        runtime.runLifecycle(
            LoopSchedule(
                fixedUpdateCount: 2,
                firstTickIndex: 1,
                fixedDeltaSeconds: 1.0 / 60.0,
                frameTimeSeconds: 1.0 / 60.0,
                updateTime: .init(
                    frameIndex: 1,
                    deltaSeconds: 1.0 / 60.0,
                    elapsedSeconds: 1.0 / 60.0
                ),
                renderTime: .init(frameIndex: 1, interpolation: 0)
            )
        )

        let recorded = recorder.snapshot()
        #expect(recorded.fixed.sorted() == [0, 0, 1, 1, 2, 2])
        #expect(recorded.update.sorted() == [0, 1, 2])
    }
}

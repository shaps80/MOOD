import Observation
import QuartzCore

struct RenderDiagnostics: Sendable {
    let visibleCount: Int?
    let cpuSimulationTime: Double
    let fixedUpdateTime: Double?
    let cpuRenderTime: Double?
    let gpuTime: Double?
    let frameBudget: Double
    let presentationFrameCount: Int
    let presentationDuration: Double
}

@MainActor
@Observable
final class RenderMetrics {
    private static let window = 3.0
    private static let publishInterval = 0.25
    private static let capacity = 2_048

    private var timestamps = [Double](repeating: 0, count: capacity)
    private var durations = [Double](repeating: 0, count: capacity)
    private var cpuSimulationTimes = [Double](repeating: 0, count: capacity)
    private var fixedUpdateTimes = [Double](repeating: 0, count: capacity)
    private var hasFixedUpdateTimes = [Bool](repeating: false, count: capacity)
    private var cpuRenderTimes = [Double](repeating: 0, count: capacity)
    private var gpuTimes = [Double](repeating: 0, count: capacity)
    private var head = 0
    private var count = 0
    private var durationSum = 0.0
    private var cpuSimulationSum = 0.0
    private var fixedUpdateSum = 0.0
    private var cpuRenderSum = 0.0
    private var gpuSum = 0.0
    private var previousTime: Double?
    private var lastPublishTime = 0.0
    private var latestVisibleCount = 0
    private var latestFrameBudget = 0.0

    private(set) var visibleCount = 0
    private(set) var framesPerSecond = 0.0
    private(set) var frameTimeMilliseconds = 0.0
    private(set) var cpuSimulationMilliseconds = 0.0
    private(set) var cpuRenderMilliseconds = 0.0
    private(set) var gpuMilliseconds = 0.0
    private(set) var cpuBudget = 0.0

    func record(_ diagnostics: RenderDiagnostics) {
        let now = CACurrentMediaTime()
        if let visibleCount = diagnostics.visibleCount {
            latestVisibleCount = visibleCount
        }
        latestFrameBudget = diagnostics.frameBudget
        if let previousTime {
            let duration = now - previousTime
            if duration <= 1 {
                append(
                    time: now,
                    duration: duration,
                    cpuSimulationTime: diagnostics.cpuSimulationTime,
                    fixedUpdateTime: diagnostics.fixedUpdateTime,
                    cpuRenderTime: diagnostics.cpuRenderTime ?? 0,
                    gpuTime: diagnostics.gpuTime ?? 0
                )
                removeSamples(olderThan: now - Self.window)
            } else {
                resetSamples()
            }
        }
        self.previousTime = now

        guard now - lastPublishTime >= Self.publishInterval else { return }
        lastPublishTime = now
        self.visibleCount = latestVisibleCount
        guard count > 0, durationSum > 0 else { return }
        cpuSimulationMilliseconds = fixedUpdateSum / Double(count) * 1_000
        cpuRenderMilliseconds = cpuRenderSum / Double(count) * 1_000
        gpuMilliseconds = gpuSum / Double(count) * 1_000
        let cpuTime = (cpuSimulationSum + cpuRenderSum) / Double(count)
        if latestFrameBudget > 0 {
            cpuBudget = cpuTime / latestFrameBudget
        }
        if diagnostics.presentationFrameCount > 0,
           diagnostics.presentationDuration > 0 {
            framesPerSecond = Double(diagnostics.presentationFrameCount)
                / diagnostics.presentationDuration
            frameTimeMilliseconds = diagnostics.presentationDuration
                / Double(diagnostics.presentationFrameCount) * 1_000
        }
    }

    private func append(
        time: Double,
        duration: Double,
        cpuSimulationTime: Double,
        fixedUpdateTime: Double?,
        cpuRenderTime: Double,
        gpuTime: Double
    ) {
        if count == Self.capacity {
            durationSum -= durations[head]
            cpuSimulationSum -= cpuSimulationTimes[head]
            removeFixedUpdate(at: head)
            cpuRenderSum -= cpuRenderTimes[head]
            gpuSum -= gpuTimes[head]
            head = (head + 1) % Self.capacity
            count -= 1
        }
        let index = (head + count) % Self.capacity
        timestamps[index] = time
        durations[index] = duration
        cpuSimulationTimes[index] = cpuSimulationTime
        hasFixedUpdateTimes[index] = false
        if let fixedUpdateTime {
            fixedUpdateTimes[index] = fixedUpdateTime
            hasFixedUpdateTimes[index] = true
            fixedUpdateSum += fixedUpdateTime
        }
        cpuRenderTimes[index] = cpuRenderTime
        gpuTimes[index] = gpuTime
        durationSum += duration
        cpuSimulationSum += cpuSimulationTime
        cpuRenderSum += cpuRenderTime
        gpuSum += gpuTime
        count += 1
    }

    private func removeSamples(olderThan cutoff: Double) {
        while count > 0, timestamps[head] < cutoff {
            durationSum -= durations[head]
            cpuSimulationSum -= cpuSimulationTimes[head]
            removeFixedUpdate(at: head)
            cpuRenderSum -= cpuRenderTimes[head]
            gpuSum -= gpuTimes[head]
            head = (head + 1) % Self.capacity
            count -= 1
        }
    }

    private func resetSamples() {
        head = 0
        count = 0
        durationSum = 0
        cpuSimulationSum = 0
        fixedUpdateSum = 0
        cpuRenderSum = 0
        gpuSum = 0

        for index in hasFixedUpdateTimes.indices {
            hasFixedUpdateTimes[index] = false
        }
    }

    private func removeFixedUpdate(at index: Int) {
        guard hasFixedUpdateTimes[index] else { return }

        fixedUpdateSum -= fixedUpdateTimes[index]
        hasFixedUpdateTimes[index] = false
    }
}

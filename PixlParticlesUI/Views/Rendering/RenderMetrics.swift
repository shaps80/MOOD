import Observation
import QuartzCore

struct RenderDiagnostics: Sendable {
    let visibleCount: Int?
    let cpuSimulationTime: Double
    let cpuRenderTime: Double?
    let gpuTime: Double?
    let frameBudget: Double
    let presentationCount: UInt64
    let presentationTime: Double?
}

@MainActor
@Observable
final class RenderMetrics {
    private static let window = 5.0
    private static let publishInterval = 0.25
    private static let capacity = 2_048

    private var timestamps = [Double](repeating: 0, count: capacity)
    private var durations = [Double](repeating: 0, count: capacity)
    private var cpuSimulationTimes = [Double](repeating: 0, count: capacity)
    private var cpuRenderTimes = [Double](repeating: 0, count: capacity)
    private var gpuTimes = [Double](repeating: 0, count: capacity)
    private var presentationTimestamps = [Double](repeating: 0, count: capacity)
    private var presentationDurations = [Double](repeating: 0, count: capacity)
    private var presentationCounts = [UInt64](repeating: 0, count: capacity)
    private var head = 0
    private var count = 0
    private var durationSum = 0.0
    private var cpuSimulationSum = 0.0
    private var cpuRenderSum = 0.0
    private var gpuSum = 0.0
    private var presentationHead = 0
    private var presentationSampleCount = 0
    private var presentationDurationSum = 0.0
    private var presentationFrameSum: UInt64 = 0
    private var previousPresentationCount: UInt64?
    private var previousPresentationTime: Double?
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
    private(set) var gpuBudget = 0.0
    private(set) var combinedBudget = 0.0

    func record(_ diagnostics: RenderDiagnostics) {
        let now = CACurrentMediaTime()
        if let visibleCount = diagnostics.visibleCount {
            latestVisibleCount = visibleCount
        }
        latestFrameBudget = diagnostics.frameBudget
        recordPresentation(diagnostics)
        if let previousTime {
            let duration = now - previousTime
            if duration <= 1 {
                append(
                    time: now,
                    duration: duration,
                    cpuSimulationTime: diagnostics.cpuSimulationTime,
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
        cpuSimulationMilliseconds = cpuSimulationSum / Double(count) * 1_000
        cpuRenderMilliseconds = cpuRenderSum / Double(count) * 1_000
        gpuMilliseconds = gpuSum / Double(count) * 1_000
        let cpuTime = (cpuSimulationSum + cpuRenderSum) / Double(count)
        let gpuTime = gpuSum / Double(count)
        if latestFrameBudget > 0 {
            cpuBudget = cpuTime / latestFrameBudget
            gpuBudget = gpuTime / latestFrameBudget
            combinedBudget = max(cpuTime, gpuTime) / latestFrameBudget
        }
        if presentationFrameSum > 0, presentationDurationSum > 0 {
            framesPerSecond = Double(presentationFrameSum)
                / presentationDurationSum
            frameTimeMilliseconds = presentationDurationSum
                / Double(presentationFrameSum) * 1_000
        }
    }

    private func append(
        time: Double,
        duration: Double,
        cpuSimulationTime: Double,
        cpuRenderTime: Double,
        gpuTime: Double
    ) {
        if count == Self.capacity {
            durationSum -= durations[head]
            cpuSimulationSum -= cpuSimulationTimes[head]
            cpuRenderSum -= cpuRenderTimes[head]
            gpuSum -= gpuTimes[head]
            head = (head + 1) % Self.capacity
            count -= 1
        }
        let index = (head + count) % Self.capacity
        timestamps[index] = time
        durations[index] = duration
        cpuSimulationTimes[index] = cpuSimulationTime
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
        cpuRenderSum = 0
        gpuSum = 0
    }

    private func recordPresentation(_ diagnostics: RenderDiagnostics) {
        guard
            let time = diagnostics.presentationTime,
            let previousCount = previousPresentationCount,
            let previousTime = previousPresentationTime,
            diagnostics.presentationCount > previousCount,
            time > previousTime
        else {
            previousPresentationCount = diagnostics.presentationCount
            previousPresentationTime = diagnostics.presentationTime
            return
        }

        let duration = time - previousTime
        if duration > 1 {
            resetPresentations()
            previousPresentationCount = diagnostics.presentationCount
            previousPresentationTime = time
            return
        }
        appendPresentation(
            time: time,
            duration: duration,
            count: diagnostics.presentationCount - previousCount
        )
        previousPresentationCount = diagnostics.presentationCount
        previousPresentationTime = time
        removePresentations(olderThan: time - Self.window)
    }

    private func appendPresentation(
        time: Double,
        duration: Double,
        count: UInt64
    ) {
        if presentationSampleCount == Self.capacity {
            presentationDurationSum -= presentationDurations[presentationHead]
            presentationFrameSum -= presentationCounts[presentationHead]
            presentationHead = (presentationHead + 1) % Self.capacity
            presentationSampleCount -= 1
        }
        let index = (presentationHead + presentationSampleCount) % Self.capacity
        presentationTimestamps[index] = time
        presentationDurations[index] = duration
        presentationCounts[index] = count
        presentationDurationSum += duration
        presentationFrameSum += count
        presentationSampleCount += 1
    }

    private func removePresentations(olderThan cutoff: Double) {
        while presentationSampleCount > 0,
              presentationTimestamps[presentationHead] < cutoff {
            presentationDurationSum -= presentationDurations[presentationHead]
            presentationFrameSum -= presentationCounts[presentationHead]
            presentationHead = (presentationHead + 1) % Self.capacity
            presentationSampleCount -= 1
        }
    }

    private func resetPresentations() {
        presentationHead = 0
        presentationSampleCount = 0
        presentationDurationSum = 0
        presentationFrameSum = 0
    }
}

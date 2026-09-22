/// All presentation-window scanning, conversion, and diagnostic assembly is
/// deferred to the UI consumer, outside render execution and Metal callbacks.
@MainActor
final class ProfileConsumer {
    private static let presentationWindow = 3.0
    private static let presentationCapacity = 512
    private let capture: ProfileCapture
    private var frameSequence: UInt64?
    private var gpuSequence: UInt64?
    private var gpuTime: Double?
    private var presentationTimes = [Double](
        repeating: 0, count: presentationCapacity
    )
    private var presentationHead = 0
    private var presentationCount = 0

    init(capture: ProfileCapture) {
        self.capture = capture
    }

    func consume() -> RenderDiagnostics? {
        capture.gpuTimes.drain { sequence, duration in
            guard gpuSequence.map({ sequence > $0 }) ?? true else { return }
            gpuSequence = sequence
            gpuTime = duration
        }
        // Slot traversal is unordered. Sort here, never on callback threads,
        // so the bounded history retains the newest presentation timestamps.
        var presented: [Double] = []
        capture.presentations.drain { _, time in presented.append(time) }
        for time in presented.sorted() { recordPresentation(at: time) }

        var latest: FrameProfile?
        capture.frames.drain { sequence, frame in
            guard frameSequence.map({ sequence > $0 }) ?? true else { return }
            frameSequence = sequence
            latest = frame
        }
        guard let latest else { return nil }
        let presentation = presentationMetrics()
        let components = latest.simulationDuration.components
        let simulationTime = Double(components.seconds)
            + Double(components.attoseconds) / 1e18
        return RenderDiagnostics(
            simulatedCount: latest.simulatedCount,
            visibleCount: latest.visibleCount,
            cpuSimulationTime: simulationTime,
            fixedUpdateTime: latest.fixedUpdateTime,
            cpuRenderTime: latest.cpuRenderTime,
            gpuTime: gpuTime,
            frameBudget: latest.frameBudget,
            presentationFrameCount: presentation.frameCount,
            presentationDuration: presentation.duration
        )
    }

    private func recordPresentation(at time: Double) {
        let index: Int
        if presentationCount == Self.presentationCapacity {
            index = presentationHead
            presentationHead = (presentationHead + 1) % Self.presentationCapacity
        } else {
            index = (presentationHead + presentationCount) % Self.presentationCapacity
            presentationCount += 1
        }
        presentationTimes[index] = time
    }

    private func presentationMetrics() -> (frameCount: Int, duration: Double) {
        guard presentationCount > 1 else { return (0, 0) }
        var latest = -Double.infinity
        for offset in 0..<presentationCount {
            let index = (presentationHead + offset) % Self.presentationCapacity
            latest = max(latest, presentationTimes[index])
        }
        let cutoff = latest - Self.presentationWindow
        var earliest = Double.infinity
        var count = 0
        for offset in 0..<presentationCount {
            let index = (presentationHead + offset) % Self.presentationCapacity
            let time = presentationTimes[index]
            guard time >= cutoff, time <= latest else { continue }
            earliest = min(earliest, time)
            count += 1
        }
        guard count > 1, latest > earliest else { return (0, 0) }
        return (count - 1, latest - earliest)
    }
}

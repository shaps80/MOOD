import Foundation
import Metal
import PixlMetal
@_spi(EditorDiagnostics) import PixlParticles
import PixlRenderer
import QuartzCore
import Synchronization

@available(macOS 15, *)
@MainActor enum GPUTraceValidation {
    static func run() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { fatalError("Metal unavailable") }
        let layer = BenchmarkLayer(device: device, width: 256, height: 256)
        let platform = BenchmarkPlatform(base: try PixlMetal.Platform(device: device, layer: layer), usesCompute: true)
        let backend = try DeviceBackend(platform: platform)
        backend.capturesDiagnostics = true
        let collector = GPUTimingCollector()
        let intervals = Mutex<[GPUTraceInterval]>([])
        let cpuIntervals = Mutex<[CPUTraceInterval]>([])
        backend.onCPUTrace = { value in cpuIntervals.withLock { $0.append(value) } }
        backend.onGPUTrace = { value in intervals.withLock { $0.append(value) } }
        backend.onGPUTimings = { collector.record($0) }
        backend.traceCaptureID = 42
        let renderer = PixlParticles.Renderer(backend: backend)
        let system = System(seed: 0, spawnRate: 100_000, lifetime: 1,
                            spawnRegion: .sphere(radius: 100, domain: .volume), duration: .zero, storesRewindState: false)
        system.seek(to: .seconds(1))
        let matrix = Matrix4x4(x: [1 / 200, 0, 0, 0], y: [0, 1 / 200, 0, 0],
                              z: [0, 0, -1 / 1000, 0], w: [0, 0, 0.5, 1])
        let camera = CameraFrame(viewProjection: matrix, position: [0, 0, 600],
                                 right: [1, 0, 0], up: [0, 1, 0],
                                 viewport: .init(width: 256, height: 256))
        for id in 1...4 {
            backend.traceFrameID = UInt64(id)
            let before = CACurrentMediaTime()
            try renderer.render(system, renderer: .init(mode: id % 2 == 0 ? .billboard : .point),
                                values: .init(size: [1, 2]), interpolation: 0.5,
                                cullingViewProjection: matrix, camera: camera)
            let timings = try collector.take()
            let after = CACurrentMediaTime()
            let values = intervals.withLock { values in
                let result = values; values.removeAll(keepingCapacity: true); return result
            }
            let cpu = cpuIntervals.withLock { values in
                let result = values; values.removeAll(keepingCapacity: true); return result
            }
            precondition(cpu.map(\.phase) == [.frameWait, .buffers, .commandBuffer, .computeEncoding,
                                                .composition, .drawableWait, .drawEncoding, .submission])
            precondition(cpu.allSatisfy { $0.frameID == UInt64(id) && $0.captureID == 42 && $0.end >= $0.start })
            for pair in zip(cpu, cpu.dropFirst()) { precondition(pair.0.end == pair.1.start) }
            precondition(values.contains { $0.computePhase == .rasterClear })
            precondition(values.contains { $0.computePhase == .rasterCoverage })
            if id % 2 == 0 {
                precondition(values.contains { $0.computePhase == .depthSeed })
                precondition(values.contains { $0.computePhase == .depthHierarchy })
                precondition(values.contains { $0.computePhase == .compactSurvivors })
                precondition(values.contains { $0.computePhase == .refineCoverage })
            }
            precondition(!values.isEmpty)
            precondition(values.allSatisfy { $0.frameID == UInt64(id) && $0.captureID == 42 })
            precondition(values.allSatisfy { $0.start.isFinite && $0.end.isFinite && $0.end >= $0.start
                && $0.start >= before - 0.01 && $0.end <= after + 0.01 })
            func verify(_ phase: GPUTraceInterval.Phase, _ duration: Double?) {
                guard let duration else { return }
                let sum = values.filter { $0.phase == phase }.reduce(0) { $0 + $1.end - $1.start }
                precondition(abs(sum - duration) < 0.00001, "Trace duration differs from counters")
            }
            verify(.frame, timings.total); verify(.preparation, timings.preparation)
            verify(.diagnostics, timings.diagnostics); verify(.vertex, timings.vertex)
            verify(.fragment, timings.fragment)
            print("Frame \(id): \(values.count) calibrated intervals, correlation and durations match")
        }
        backend.traceCaptureID = nil // Frozen: don't submit new trace work.
        try renderer.render(system, renderer: .init(), values: .init(), interpolation: 0.5,
                            cullingViewProjection: matrix, camera: camera)
        _ = try collector.take()
        precondition(intervals.withLock { $0.isEmpty })
        precondition(cpuIntervals.withLock { $0.isEmpty })
        print("GPU trace validation passed, including disabled capture")
    }
}

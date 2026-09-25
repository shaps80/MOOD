import Foundation
import Metal
import PixlMetal
import PixlRenderer

/// Checks telemetry separately from image equality, including partial SIMD groups
/// and readback slots that retain older samples between UI refreshes.
@MainActor
enum VisibilityValidation {
    static func run() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let matrix = Matrix4x4(x: [1, 0, 0, 0], y: [0, 1, 0, 0],
                              z: [0, 0, -0.125, 0], w: [0, 0, 0.5, 1])
        let camera = CameraFrame(viewProjection: matrix, position: [0, 0, 10],
            right: [1, 0, 0], up: [0, 1, 0], viewport: .init(width: 64, height: 64))
        var checks = 0
        for automatic in [false, true] {
            for alpha: Float in [1, 0.4] {
                for mode: ParticleRenderer.Mode in [.point, .billboard] {
                    for count in [0, 1, 31, 32, 33, 127, 128, 129, 65_537] {
                        let layer = BenchmarkLayer(device: device, width: 64, height: 64)
                        let platform = BenchmarkPlatform(base: try PixlMetal.Platform(device: device, layer: layer), usesCompute: automatic)
                        let backend = try DeviceBackend(platform: platform, pointLOD: .init(isEnabled: false))
                        backend.capturesDiagnostics = true
                        let collector = GPUTimingCollector()
                        backend.onGPUTimings = { collector.record($0) }
                        let buffers = RasterOrderValidation.fixture(count: max(count, 1), colors: [[alpha, 0, 0, alpha]])
                        buffers.currentPositions.withUnsafeBytes { bytes in
                            let positions = UnsafeMutableRawPointer(mutating: bytes.baseAddress!).assumingMemoryBound(to: Float.self)
                            for index in 0..<count where index % 3 != 0 {
                                positions[index / 4 * 12 + index % 4] = 1000
                            }
                        }
                        for _ in 0..<3 {
                            try backend.renderParticles(count: count, buffers: buffers,
                                renderer: .init(mode: mode, billboard: .init(facing: .cameraPlane)),
                                values: .init(size: [0.125, 0.125]), interpolation: 1,
                                cullingViewProjection: matrix, camera: camera)
                            _ = try collector.take()
                        }
                        precondition(backend.visibleCount == (count + 2) / 3,
                            "Visibility count mismatch: automatic=\(automatic), alpha=\(alpha), mode=\(mode), count=\(count), actual=\(String(describing: backend.visibleCount))")
                        checks += 1
                    }
                }
            }
        }
        // A newer zero count must not bounce back to an older count when the
        // other in-flight readback slot is reused without a new capture.
        for automatic in [false, true] {
            let layer = BenchmarkLayer(device: device, width: 64, height: 64)
            let platform = BenchmarkPlatform(base: try PixlMetal.Platform(device: device, layer: layer), usesCompute: automatic)
            let backend = try DeviceBackend(platform: platform, pointLOD: .init(isEnabled: false))
            backend.capturesDiagnostics = true
            let collector = GPUTimingCollector()
            backend.onGPUTimings = { collector.record($0) }
            let buffers = RasterOrderValidation.fixture(count: 65_537, colors: [[1, 0, 0, 1]])
            func frame(_ transform: Matrix4x4) throws {
                try backend.renderParticles(count: 65_537, buffers: buffers,
                    renderer: .init(mode: .billboard, billboard: .init(facing: .cameraPlane)),
                    values: .init(size: [4, 4]), interpolation: 1,
                    cullingViewProjection: transform, camera: camera)
                _ = try collector.take()
            }
            for _ in 0..<3 { try frame(matrix) }
            precondition(backend.visibleCount == 65_537, "Oversized fallback count mismatch")
            Thread.sleep(forTimeInterval: 0.21)
            let outside = Matrix4x4(x: matrix.x, y: matrix.y, z: matrix.z, w: [1000, 0, 0.5, 1])
            for _ in 0..<3 { try frame(outside) }
            precondition(backend.visibleCount == 0)
            for _ in 0..<4 { try frame(outside); precondition(backend.visibleCount == 0) }
            checks += 2
        }
        print("Visibility checks: \(checks) passed"); fflush(nil)
    }
}

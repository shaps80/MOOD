import Foundation
import Metal
import PixlMetal
import PixlRenderer

@MainActor
enum RasterBoundaryValidation {
    static func run() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let opaque = RasterOrderValidation.fixture(count: 65_537, colors: [[1, 0, 0, 1], [0, 0, 1, 1]])
        let alpha = RasterOrderValidation.fixture(count: 65_537, colors: [[0.4, 0, 0, 0.4], [0, 0, 0.7, 0.7]])
        let near = RasterOrderValidation.fixture(count: 65_537, colors: [[1, 0, 0, 1], [0, 0, 1, 1]], nearLast: true)
        let sizes = [(64, 64), (128, 32), (64, 64), (64, 64), (64, 64), (64, 64)]
        let sources = [opaque, opaque, near, opaque, alpha, opaque]
        var images: [[Data]] = []
        for automatic in [false, true] {
            let layer = BenchmarkLayer(device: device, width: 64, height: 64)
            let platform = BenchmarkPlatform(base: try PixlMetal.Platform(device: device, layer: layer), usesCompute: automatic)
            let backend = try DeviceBackend(platform: platform, pointLOD: .init(isEnabled: false))
            backend.capturesDiagnostics = true
            let collector = GPUTimingCollector()
            backend.onGPUTimings = { collector.record($0) }
            var frames: [Data] = []
            for step in sources.indices {
                let (width, height) = sizes[step]
                layer.resize(width: width, height: height)
                let matrix = step == 2
                    ? Matrix4x4(x: [1, 0, 0, 0], y: [0, 1, 0, 0], z: [0, 0, -10 / 9, -1], w: [0, 0, 10, 10])
                    : Matrix4x4(x: [1, 0, 0, 0], y: [0, 1, 0, 0], z: [0, 0, -0.125, 0], w: [0, 0, 0.5, 1])
                let camera = CameraFrame(viewProjection: matrix, position: [0, 0, 10],
                    right: [1, 0, 0], up: [0, 1, 0], viewport: .init(width: UInt32(width), height: UInt32(height)))
                try backend.renderParticles(count: 65_537, buffers: sources[step],
                    renderer: .init(mode: .billboard, billboard: .init(facing: step == 2 ? .camera : .cameraPlane)),
                    values: .init(size: step == 2 ? [4, 4] : [0.125, 0.125]), interpolation: 1,
                    cullingViewProjection: matrix, camera: camera)
                _ = try collector.take()
                let path = NSTemporaryDirectory() + UUID().uuidString + ".rgba16f"
                try MetalRenderBenchmarks.capture(texture: layer.offscreen.texture, device: device, path: path)
                frames.append(try Data(contentsOf: URL(fileURLWithPath: path)))
                try FileManager.default.removeItem(atPath: path)
            }
            images.append(frames)
        }
        for step in sources.indices {
            print("Resize/near/opacity transition \(step): \(images[0][step] == images[1][step] ? "exact" : "MISMATCH")")
            fflush(nil)
            precondition(images[0][step] == images[1][step])
        }
    }
}

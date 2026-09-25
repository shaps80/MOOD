import Foundation
import Metal
import PixlMetal
@_spi(EditorDiagnostics) import PixlParticles
import PixlRenderer

/// Image comparison exercises both production paths without an application toggle.
@MainActor
enum PointValidation {
    static func run() throws {
        let device = MTLCreateSystemDefaultDevice()!
        for (name, count, width, height, alpha, perspective) in [
            ("dense", 2_000_000, 2852, 1916, Float(1), false),
            ("odd dimensions", 300_003, 801, 603, 1, false),
            ("perspective", 300_003, 801, 603, 1, true),
            ("transparent", 300_003, 801, 603, 0.4, true),
            ("sparse", 127, 801, 603, 1, false)
        ] {
            let system = System(seed: 0, spawnRate: Float(count), lifetime: 1,
                spawnRegion: .sphere(radius: 150, domain: .surface),
                color: .init(red: 0.25, green: 1.5, blue: 0.75, alpha: alpha),
                duration: .zero, storesRewindState: false)
            system.seek(to: .seconds(1))
            let aspect = Float(width) / Float(height)
            let matrix = perspective
                ? Matrix4x4(x: [2 / aspect, 0, 0, 0], y: [0, 2, 0, 0],
                            z: [0, 0, -1.001, -1], w: [0, 0, 599.6, 600])
                : Matrix4x4(x: [1 / (200 * aspect), 0, 0, 0], y: [0, 1 / 200, 0, 0],
                            z: [0, 0, -1 / 1000, 0], w: [0, 0, 0.5, 1])
            let camera = CameraFrame(viewProjection: matrix, position: [0, 0, 600],
                right: [1, 0, 0], up: [0, 1, 0],
                viewport: .init(width: UInt32(width), height: UInt32(height)))
            var images: [Data] = []
            for optimized in [false, true] {
                let layer = BenchmarkLayer(device: device, width: width, height: height)
                let platform = BenchmarkPlatform(base: try PixlMetal.Platform(device: device, layer: layer), usesCompute: optimized)
                let backend = try DeviceBackend(platform: platform, pointLOD: .init(isEnabled: false))
                backend.capturesDiagnostics = true
                let collector = GPUTimingCollector()
                backend.onGPUTimings = { collector.record($0) }
                let renderer = PixlParticles.Renderer(backend: PaletteValidationBackend(base: backend, count: system.particleCount, alpha: alpha))
                for _ in 0..<3 {
                    try renderer.render(system, renderer: .init(mode: .point), values: .init(),
                        interpolation: 0.5, cullingViewProjection: matrix, camera: camera)
                    _ = try collector.take()
                }
                let path = NSTemporaryDirectory() + UUID().uuidString + ".rgba16f"
                try MetalRenderBenchmarks.capture(texture: layer.offscreen.texture, device: device, path: path)
                images.append(try Data(contentsOf: URL(fileURLWithPath: path)))
                try FileManager.default.removeItem(atPath: path)
            }
            let differences = images[0].withUnsafeBytes { (a: UnsafeRawBufferPointer) in
                images[1].withUnsafeBytes { (b: UnsafeRawBufferPointer) in
                    zip(a.bindMemory(to: UInt64.self), b.bindMemory(to: UInt64.self)).filter { $0 != $1 }.count
                }
            }
            print("\(name): \(differences) differing pixels / \(width * height)")
            // Compute and fixed-function viewport rounding can disagree at a
            // subpixel boundary. Fallbacks must be bit-identical.
            precondition(differences <= (alpha < 1 || count < 65_536 ? 0 : width * height / 10000))
        }
    }
}

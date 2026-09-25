import Foundation
import Metal
import PixlMetal
import PixlRenderer

/// Deliberately overlapping particles detect ordering, equal-depth, alpha-zero
/// depth writes and partial SIMD-batch errors that a large-image tolerance hides.
@MainActor
enum RasterOrderValidation {
    static func run() throws {
        let device = MTLCreateSystemDefaultDevice()!
        let matrix = Matrix4x4(x: [1, 0, 0, 0], y: [0, 1, 0, 0],
                              z: [0, 0, -0.125, 0], w: [0, 0, 0.5, 1])
        let camera = CameraFrame(viewProjection: matrix, position: [0, 0, 10],
            right: [1, 0, 0], up: [0, 1, 0], viewport: .init(width: 64, height: 64))
        for (name, count, colors) in [
            ("ordered alpha", 67, [SIMD4<Float>(0.4, 0, 0, 0.4), SIMD4<Float>(0, 0.7, 0, 0.7)]),
            ("zero alpha depth", 67, [SIMD4<Float>(repeating: 0), SIMD4<Float>(0, 0, 1, 1)]),
            ("opaque depth ties", 65_537, [SIMD4<Float>(1, 0, 0, 1), SIMD4<Float>(0, 0, 1, 1), SIMD4<Float>(0, 1, 0, 1)])
        ] {
            let buffers = fixture(count: count, colors: colors, zeroFirst: name == "zero alpha depth")
            for mode: ParticleRenderer.Mode in [.point, .billboard] {
                var images: [Data] = []
                for automatic in [false, true] {
                    let layer = BenchmarkLayer(device: device, width: 64, height: 64)
                    let platform = BenchmarkPlatform(base: try PixlMetal.Platform(device: device, layer: layer), usesCompute: automatic)
                    let backend = try DeviceBackend(platform: platform, pointLOD: .init(isEnabled: false))
                    backend.capturesDiagnostics = true
                    let collector = GPUTimingCollector()
                    backend.onGPUTimings = { collector.record($0) }
                    try backend.renderParticles(count: count, buffers: buffers,
                        renderer: .init(mode: mode, billboard: .init(facing: .cameraPlane)),
                        values: .init(size: [0.125, 0.125]), interpolation: 1,
                        cullingViewProjection: matrix, camera: camera)
                    _ = try collector.take()
                    let path = NSTemporaryDirectory() + UUID().uuidString + ".rgba16f"
                    try MetalRenderBenchmarks.capture(texture: layer.offscreen.texture, device: device, path: path)
                    images.append(try Data(contentsOf: URL(fileURLWithPath: path)))
                    try FileManager.default.removeItem(atPath: path)
                }
                print("Order check: \(name) \(mode)"); fflush(nil)
                precondition(images[0] == images[1], "Order mismatch: \(name) \(mode)")
                print("\(name) \(mode): exact")
            }
        }
    }

    static func fixture(count: Int, colors: [SIMD4<Float>], zeroFirst: Bool = false, nearLast: Bool = false) -> ParticleBuffers {
        let batches = (count + 3) / 4
        let positions = HostBuffer(byteCount: batches * 48)
        positions.withUnsafeBytes { bytes in
            let pointer = UnsafeMutableRawPointer(mutating: bytes.baseAddress!).bindMemory(to: Float.self, capacity: batches * 12)
            pointer.initialize(repeating: 0, count: batches * 12)
            for index in 0..<count {
                let offset = index / 4 * 12 + index % 4
                pointer[offset] = 0.03125
                pointer[offset + 4] = 0.03125
                pointer[offset + 8] = zeroFirst ? (index == 0 ? 3 : 0) : [Float(0), 2, 1, 3][index % 4]
                if nearLast {
                    pointer[offset] = index == count - 1 ? 1 : 1000
                    pointer[offset + 4] = index == count - 1 ? 1 : 0
                    pointer[offset + 8] = index == count - 1 ? 8.9 : 0
                }
            }
        }
        let displacement = HostBuffer(byteCount: batches * 16)
        displacement.withUnsafeBytes { bytes in
            _ = UnsafeMutableRawPointer(mutating: bytes.baseAddress!).initializeMemory(as: UInt8.self, repeating: 0, count: bytes.count)
        }
        let indices = HostBuffer(byteCount: batches * 8)
        indices.withUnsafeBytes { bytes in
            let pointer = UnsafeMutableRawPointer(mutating: bytes.baseAddress!).bindMemory(to: UInt16.self, capacity: batches * 4)
            for index in 0..<(batches * 4) { (pointer + index).initialize(to: UInt16(index % colors.count)) }
        }
        let palette = HostBuffer(byteCount: colors.count * 16)
        palette.withUnsafeBytes { bytes in
            let pointer = UnsafeMutableRawPointer(mutating: bytes.baseAddress!).bindMemory(to: SIMD4<Float>.self, capacity: colors.count)
            for index in colors.indices { (pointer + index).initialize(to: colors[index]) }
        }
        return .init(capacity: batches * 4, displacements: displacement, displacementScale: 0,
                     currentPositions: positions, colorIndices: indices, colorPalette: palette,
                     ids: .init(byteCount: batches * 16))
    }
}

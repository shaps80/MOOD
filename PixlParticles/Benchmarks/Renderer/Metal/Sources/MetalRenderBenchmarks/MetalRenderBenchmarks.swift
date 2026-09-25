import Foundation
import Metal
import PixlMetal
@_spi(EditorDiagnostics) import PixlParticles
import PixlRenderer
import QuartzCore

@main
@MainActor
struct MetalRenderBenchmarks {
    static func main() throws {
        if CommandLine.arguments.contains("validate-trace") {
            if #available(macOS 15, *) { try GPUTraceValidation.run() }
            else { fatalError("Trace validation requires macOS 15") }
            return
        }
        if CommandLine.arguments.contains("validate-visibility") { try VisibilityValidation.run(); return }
        if CommandLine.arguments.contains("validate-boundaries") { try RasterBoundaryValidation.run(); return }
        if CommandLine.arguments.contains("validate") { try RasterValidation.run(); return }
        let args = CommandLine.arguments.dropFirst().prefix(3).compactMap(Int.init)
        let options = Array(CommandLine.arguments.dropFirst(4))
        let capturePrefix = options.first { !["translucent", "quick", "automatic-only"].contains($0) && !$0.hasPrefix("zoom=") && !$0.hasPrefix("size=") }
        let zoom = options.first { $0.hasPrefix("zoom=") }.flatMap { Float($0.dropFirst(5)) } ?? 1
        let size = options.first { $0.hasPrefix("size=") }.flatMap { Float($0.dropFirst(5)) } ?? 1
        precondition(zoom.isFinite && zoom > 0 && size.isFinite && size > 0)
        let translucent = CommandLine.arguments.contains("translucent")
        let quick = CommandLine.arguments.contains("quick")
        let warmup = capturePrefix == nil && !quick ? 30 : 2
        let measured = capturePrefix == nil && !quick ? 180 : 1
        let count = args.first ?? 2_000_000
        let width = args.count > 1 ? args[1] : 1920
        let height = args.count > 2 ? args[2] : 1080
        precondition(count > 0 && width > 0 && height > 0)
        guard let device = MTLCreateSystemDefaultDevice() else { fatalError("Metal unavailable") }
        for optimized in (options.contains("automatic-only") ? [true] : [false, true]) {
            let layer = BenchmarkLayer(device: device, width: width, height: height)
            let platform = BenchmarkPlatform(base: try PixlMetal.Platform(device: device, layer: layer), usesCompute: optimized)
            print("Path: \(optimized ? "automatic" : "hardware reference")")
            let backend = try DeviceBackend(platform: platform, pointLOD: .init(isEnabled: false))
            backend.capturesDiagnostics = true
            let collector = GPUTimingCollector()
            backend.onGPUTimings = { collector.record($0) }
            let renderer = PixlParticles.Renderer(backend: backend)
            let system = System(seed: 0, spawnRate: Float(count), lifetime: 1,
                                spawnRegion: .sphere(radius: 150, domain: .surface),
                                color: .init(red: 1, green: 1, blue: 1, alpha: translucent ? 0.4 : 1),
                                duration: .zero, storesRewindState: false)
            system.seek(to: .seconds(1))
            let aspect = Float(width) / Float(height)
            let matrix = Matrix4x4(x: [zoom / (200 * aspect), 0, 0, 0],
                                  y: [0, zoom / 200, 0, 0], z: [0, 0, -1 / 1000, 0],
                                  w: [0, 0, 0.5, 1])
            let camera = CameraFrame(viewProjection: matrix, position: [0, 0, 600],
                                     right: [1, 0, 0], up: [0, 1, 0],
                                     viewport: .init(width: UInt32(width), height: UInt32(height)))
            print("Device: \(device.name); particles: \(system.particleCount); drawable: \(width)x\(height); zoom: \(zoom); size: \(size)")
            print("Production renderer; paused seeded sphere; \(warmup) warmup + \(measured) measured frames per mode.")
            print("Draw excludes editor guides. Stages may overlap; do not sum stage times.")
            for mode: ParticleRenderer.Mode in [.point, .billboard] {
                var samples: [GPUFrameTimings] = []
                samples.reserveCapacity(measured)
                for frame in 0..<(warmup + measured) {
                    let sample = try autoreleasepool {
                        try renderer.render(system, renderer: .init(mode: mode), values: .init(size: [size, size]),
                                            interpolation: 0.5, cullingViewProjection: matrix, camera: camera)
                        return try collector.take()
                    }
                    if frame >= warmup { samples.append(sample) }
                }
                print("Mode: \(mode)")
                GPUTimingReport(samples: samples).printRows()
                var memory = task_vm_info_data_t()
                var memoryCount = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
                let status = withUnsafeMutablePointer(to: &memory) { pointer in
                    pointer.withMemoryRebound(to: integer_t.self, capacity: Int(memoryCount)) {
                        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &memoryCount)
                    }
                }
                if status == KERN_SUCCESS { print("Process footprint MB: \(Double(memory.phys_footprint) / 1_000_000)") }
                print("Metal allocated MB: \(Double(device.currentAllocatedSize) / 1_000_000)")
                fflush(nil)
                if let capturePrefix {
                    try capture(texture: layer.offscreen.texture, device: device, path: "\(capturePrefix)-\(optimized ? "automatic" : "reference")-\(mode).rgba16f")
                }
            }
        }
    }

    static func capture(texture: any MTLTexture, device: any MTLDevice, path: String) throws {
        let row = texture.width * 8
        guard let buffer = device.makeBuffer(length: row * texture.height, options: .storageModeShared),
              let queue = device.makeCommandQueue(), let command = queue.makeCommandBuffer(),
              let blit = command.makeBlitCommandEncoder() else { fatalError("Readback unavailable") }
        blit.copy(from: texture, sourceSlice: 0, sourceLevel: 0,
                  sourceOrigin: .init(x: 0, y: 0, z: 0),
                  sourceSize: .init(width: texture.width, height: texture.height, depth: 1),
                  to: buffer, destinationOffset: 0, destinationBytesPerRow: row,
                  destinationBytesPerImage: row * texture.height)
        blit.endEncoding()
        command.commit()
        command.waitUntilCompleted()
        precondition(command.status == .completed)
        try Data(bytes: buffer.contents(), count: buffer.length).write(to: URL(fileURLWithPath: path))
    }
}

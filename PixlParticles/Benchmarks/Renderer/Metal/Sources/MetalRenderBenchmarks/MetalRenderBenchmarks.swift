import AppKit
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
        let args = CommandLine.arguments.dropFirst().compactMap(Int.init)
        let count = args.first ?? 2_000_000
        let width = args.count > 1 ? args[1] : 1920
        let height = args.count > 2 ? args[2] : 1080
        precondition(count > 0 && width > 0 && height > 0)
        guard let device = MTLCreateSystemDefaultDevice() else { fatalError("Metal unavailable") }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Pixl GPU Benchmark"
        let layer = CAMetalLayer()
        layer.device = device
        layer.pixelFormat = .rgba16Float
        layer.framebufferOnly = true
        layer.maximumDrawableCount = 3
        layer.displaySyncEnabled = false
        layer.drawableSize = CGSize(width: width, height: height)
        let view = NSView(frame: window.contentView!.bounds)
        view.wantsLayer = true
        view.layer = layer
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()

        let platform = try PixlMetal.Platform(device: device, layer: layer)
        let backend = try DeviceBackend(platform: platform, pointLOD: .init(isEnabled: false))
        backend.capturesDiagnostics = true
        let collector = GPUTimingCollector()
        backend.onGPUTimings = { collector.record($0) }
        let renderer = PixlParticles.Renderer(backend: backend)
        let system = System(seed: 0, spawnRate: Float(count), lifetime: 1,
                            spawnRegion: .sphere(radius: 150, domain: .surface),
                            duration: .zero, storesRewindState: false)
        system.seek(to: .seconds(1))
        let aspect = Float(width) / Float(height)
        let matrix = Matrix4x4(x: [1 / (200 * aspect), 0, 0, 0],
                              y: [0, 1 / 200, 0, 0], z: [0, 0, -1 / 1000, 0],
                              w: [0, 0, 0.5, 1])
        let camera = CameraFrame(viewProjection: matrix, position: [0, 0, 600],
                                 right: [1, 0, 0], up: [0, 1, 0],
                                 viewport: .init(width: UInt32(width), height: UInt32(height)))
        print("Device: \(device.name); particles: \(system.particleCount); drawable: \(width)x\(height)")
        print("Production renderer; paused seeded sphere; 30 warmup + 180 measured frames per mode.")
        print("Draw excludes editor guides. Stages may overlap; do not sum stage times.")
        for mode: ParticleRenderer.Mode in [.point, .billboard] {
            var samples: [GPUFrameTimings] = []
            samples.reserveCapacity(180)
            for frame in 0..<210 {
                let sample = try autoreleasepool {
                    while let event = app.nextEvent(matching: .any, until: .distantPast,
                                                    inMode: .default, dequeue: true) { app.sendEvent(event) }
                    try renderer.render(system, renderer: .init(mode: mode), values: .init(),
                                        interpolation: 0.5, cullingViewProjection: matrix, camera: camera)
                    return try collector.take()
                }
                if frame >= 30 { samples.append(sample) }
            }
            print("Mode: \(mode)")
            GPUTimingReport(samples: samples).printRows()
        }
        withExtendedLifetime(window) {}
    }
}

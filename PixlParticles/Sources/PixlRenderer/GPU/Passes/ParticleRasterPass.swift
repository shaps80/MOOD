import Swift

/// Shared particle projection. Opaque coverage resolves nearest depth in compute;
/// ordered geometry retains exact hardware alpha blending without fragment lists.
final class ParticleRasterPass {
    private static let maximumComputeFootprint: UInt32 = 256

    private let platform: any Platform
    private let clear: any ComputePipeline
    private let raster: any ComputePipeline
    private let pipeline: any RenderPipeline
    private let geometry: any RenderPipeline
    private let depth: any DepthState
    private var fallbackArguments: (any Buffer)?
    private var usesCompute = false
    private var winners: (any Buffer)?
    private var dimensions = SIMD2<Int>.zero
    private var cachedPalette: HostBuffer?
    private var isOpaque = false
    private var count = 0

    init(platform: any Platform) throws {
        self.platform = platform
        guard let clear = platform.makeComputePipeline(function: "clearParticleRaster"),
              let raster = platform.makeComputePipeline(function: "rasterParticles"),
              let pipeline = platform.makeRenderPipeline(.init(vertexFunction: "particleRasterVertex",
                  fragmentFunction: "particleRasterFragment", colorFormat: .rgba16Float,
                  depthFormat: .depth32Float, blendMode: .premultiplied)),
              let geometry = platform.makeRenderPipeline(.init(vertexFunction: "particleGeometryVertex",
                  fragmentFunction: "pointFragment", colorFormat: .rgba16Float,
                  depthFormat: .depth32Float, blendMode: .premultiplied, supportsReusableCommands: true)),
              let depth = platform.makeDepthState(compare: .less, isWriteEnabled: true)
        else { throw RenderError.pipeline }
        self.clear = clear
        self.raster = raster
        self.pipeline = pipeline
        self.geometry = geometry
        self.depth = depth
    }

    func isEligible(count: Int, viewport: ViewportSize, palette: HostBuffer) -> Bool {
        let pixels = UInt64(viewport.width) * UInt64(viewport.height)
        guard pixels > 0, pixels <= UInt64(UInt32.max), count > 0,
              count < Int(UInt32.max) else { return false }
        if cachedPalette !== palette {
            cachedPalette = palette
            isOpaque = palette.byteCount > 0 && palette.withUnsafeBytes {
                $0.bindMemory(to: SIMD4<Float>.self).allSatisfy { $0.w == 1 }
            }
        }
        return true
    }

    func releaseStorage() {
        winners = nil
        fallbackArguments = nil
        dimensions = .zero
    }

    private func configuration(_ renderer: ParticleRenderer, _ values: ParticleRenderValues) -> RasterConfiguration {
        .init(values: [values.size.x, values.size.y, values.rotation, 0],
              modes: [renderer.billboard.sizeSpace.gpuValue, renderer.billboard.facing.gpuValue,
                      renderer.mode == .point ? 0 : 1, Self.maximumComputeFootprint])
    }

    func prepare(count: Int, visibility: DirectVisibility, camera: CameraFrame,
                 interpolation: Float, displacementScale: Float,
                 displacements: any Buffer, positions: any Buffer,
                 renderer: ParticleRenderer, values: ParticleRenderValues,
                 into command: any CommandBuffer) throws {
        self.count = count
        let size = SIMD2(Int(camera.viewportSize.width), Int(camera.viewportSize.height))
        usesCompute = isOpaque && count >= max(65_536, size.x * size.y / 8)
        guard usesCompute else { releaseStorage(); return }
        if size != dimensions || winners == nil {
            winners = platform.makeBuffer(length: size.x * size.y * 8, memory: .gpuOnly)
            dimensions = size
        }
        if fallbackArguments == nil { fallbackArguments = platform.makeBuffer(length: 16, memory: .gpuOnly) }
        guard let winners, let fallbackArguments else { throw RenderError.buffer }
        guard let encoder = command.makeComputeEncoder() else { throw RenderError.encoder }
        encoder.label = "Clear Particle Raster"
        encoder.setPipeline(clear)
        encoder.setBuffer(winners, index: 0)
        encoder.setValue(UInt32(size.x * size.y), index: 1)
        encoder.setBuffer(fallbackArguments, index: 2)
        encoder.setValue(UInt32(renderer.mode == .point ? count : 4), index: 3)
        encoder.dispatchThreads(.init(width: size.x * size.y), threads: .init(width: 256))
        encoder.endEncoding()
        guard let encoder = command.makeComputeEncoder() else { throw RenderError.encoder }
        encoder.label = "Particle Coverage"
        encoder.setPipeline(raster)
        encoder.setBuffer(displacements, index: 0)
        encoder.setBuffer(positions, index: 1)
        encoder.setBuffer(winners, index: 2)
        encoder.setValue(visibility, index: 3)
        encoder.setValue(interpolation, index: 4)
        encoder.setValue(displacementScale, index: 5)
        encoder.setValue(UInt32(count), index: 6)
        encoder.setValue(camera, index: 7)
        encoder.setValue(configuration(renderer, values), index: 8)
        encoder.setBuffer(fallbackArguments, index: 9)
        encoder.dispatchThreads(.init(width: count), threads: .init(width: 128))
        encoder.endEncoding()
    }

    func encode(indices: any Buffer, palette: any Buffer, displacements: any Buffer,
                positions: any Buffer, visibility: DirectVisibility, camera: CameraFrame,
                interpolation: Float, displacementScale: Float,
                renderer: ParticleRenderer, values: ParticleRenderValues,
                into encoder: any RenderEncoder) {
        encoder.setDepthState(depth)
        if usesCompute {
            guard let winners, let fallbackArguments else { return }
            encoder.setPipeline(pipeline)
            encoder.setFragmentBuffer(winners, index: 0)
            encoder.setFragmentBuffer(indices, index: 1)
            encoder.setFragmentBuffer(palette, index: 2)
            encoder.setFragmentValue(camera.viewportSize.width, index: 3)
            encoder.setFragmentBuffer(fallbackArguments, index: 4)
            encoder.drawPrimitives(.triangleStrip, vertexStart: 0, vertexCount: 3)
        }
        encoder.setPipeline(geometry)
        encoder.setVertexBuffer(displacements, index: 0)
        encoder.setVertexBuffer(positions, index: 1)
        encoder.setVertexValue(camera, index: 2)
        encoder.setVertexValue(interpolation, index: 3)
        encoder.setVertexValue(configuration(renderer, values), index: 4)
        encoder.setVertexValue(displacementScale, index: 5)
        encoder.setVertexBuffer(indices, index: 7)
        encoder.setVertexBuffer(palette, index: 8)
        encoder.setVertexValue(visibility, index: 9)
        if usesCompute, let fallbackArguments {
            encoder.drawPrimitives(renderer.mode == .point ? .point : .triangleStrip, indirectBuffer: fallbackArguments)
        } else {
            encoder.drawReusablePrimitives(renderer.mode == .point ? .point : .triangleStrip,
                vertexCount: renderer.mode == .point ? count : 4,
                instanceCount: renderer.mode == .point ? 1 : count)
        }
    }
}

private struct RasterConfiguration: BitwiseCopyable {
    let values: SIMD4<Float>
    let modes: SIMD4<UInt32>
}

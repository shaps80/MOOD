import Swift

final class OpaquePointPass {
    private let platform: any Platform
    private let clear: any ComputePipeline
    private let raster: any ComputePipeline
    private let pipeline: any RenderPipeline
    private let depth: any DepthState
    private var winners: (any Buffer)?
    private var dimensions = SIMD2<Int>(repeating: 0)
    private var cachedPalette: HostBuffer?
    private var isOpaque = false
    private var widthBuffer: (any Buffer)?

    init(platform: any Platform) throws {
        self.platform = platform
        guard let clear = platform.makeComputePipeline(function: "clearPointWinners"),
              let raster = platform.makeComputePipeline(function: "rasterOpaquePoints"),
              let pipeline = platform.makeRenderPipeline(.init(vertexFunction: "opaquePointVertex",
                  fragmentFunction: "opaquePointFragment", colorFormat: .rgba16Float,
                  depthFormat: .depth32Float, blendMode: .premultiplied)),
              let depth = platform.makeDepthState(compare: .less, isWriteEnabled: true)
        else { throw RenderError.pipeline }
        self.clear = clear
        self.raster = raster
        self.pipeline = pipeline
        self.depth = depth
    }

    // Restrict to dense, opaque, one-pixel points. Translucent layers must retain
    // the original ordered blend; unsupported devices retain the point pipeline.
    func isEligible(count: Int, viewport: ViewportSize, palette: HostBuffer) -> Bool {
        let pixels = UInt64(viewport.width) * UInt64(viewport.height)
        guard pixels > 0, pixels <= UInt64(UInt32.max),
              count >= max(65_536, Int(pixels / 8)), count < Int(UInt32.max) else { return false }
        if cachedPalette !== palette {
            cachedPalette = palette
            isOpaque = palette.byteCount > 0 && palette.withUnsafeBytes {
                $0.bindMemory(to: SIMD4<Float>.self).allSatisfy { $0.w == 1 }
            }
        }
        return isOpaque
    }

    func releaseStorage() {
        winners = nil
        widthBuffer = nil
        dimensions = .zero
    }

    func prepare(count: Int, visibility: DirectVisibility, camera: CameraFrame,
                 interpolation: Float, displacementScale: Float,
                 displacements: any Buffer, positions: any Buffer,
                 into command: any CommandBuffer) throws {
        let width = Int(visibility.modes.z), height = Int(visibility.modes.w)
        let required = width * height
        if dimensions != SIMD2(width, height) {
            winners = platform.makeBuffer(length: required * 8, memory: .gpuOnly)
            widthBuffer = platform.makeBuffer(length: 4, memory: .cpuVisible)
            widthBuffer?.withMutableBytes { $0.storeBytes(of: UInt32(width), as: UInt32.self) }
            guard winners != nil, widthBuffer != nil else { throw RenderError.buffer }
            dimensions = SIMD2(width, height)
        }
        guard let winners, let encoder = command.makeComputeEncoder() else { throw RenderError.buffer }
        encoder.setPipeline(clear)
        encoder.setBuffer(winners, index: 0)
        encoder.setValue(UInt32(required), index: 1)
        encoder.dispatchThreads(.init(width: required), threads: .init(width: 256))
        encoder.endEncoding()
        guard let rasterEncoder = command.makeComputeEncoder() else { throw RenderError.encoder }
        rasterEncoder.setPipeline(raster)
        rasterEncoder.setBuffer(displacements, index: 0)
        rasterEncoder.setBuffer(positions, index: 1)
        rasterEncoder.setBuffer(winners, index: 2)
        rasterEncoder.setValue(visibility, index: 3)
        rasterEncoder.setValue(interpolation, index: 4)
        rasterEncoder.setValue(displacementScale, index: 5)
        rasterEncoder.setValue(UInt32(count), index: 6)
        rasterEncoder.setValue(camera.viewProjection, index: 7)
        rasterEncoder.dispatchThreads(.init(width: count), threads: .init(width: 256))
        rasterEncoder.endEncoding()
    }

    func encode(indices: any Buffer, palette: any Buffer, into encoder: any RenderEncoder) {
        guard let winners, let widthBuffer else { return }
        encoder.setPipeline(pipeline)
        encoder.setDepthState(depth)
        encoder.setFragmentBuffer(winners, index: 0)
        encoder.setFragmentBuffer(indices, index: 1)
        encoder.setFragmentBuffer(palette, index: 2)
        encoder.setFragmentBuffer(widthBuffer, index: 3)
        encoder.drawPrimitives(.triangleStrip, vertexStart: 0, vertexCount: 3)
    }
}

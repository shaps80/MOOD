import PixlEditorSupport
import PixlRenderer
import Testing

@Suite("Editor renderer")
struct RendererTests {
    @Test
    func hiddenDiagnosticsDrawNothing() throws {
        let platform = RecordingPlatform()
        let renderer = try Renderer(platform: platform)
        let encoder = RecordingRenderEncoder()

        try renderer.prepare()
        renderer.encodeBackground(into: encoder)
        renderer.encodeOverlay(into: encoder)

        #expect(encoder.draws.isEmpty)
    }

    @Test
    func diagnosticsUseTwoCategoryBatchedDraws() throws {
        let platform = RecordingPlatform()
        let renderer = try Renderer(platform: platform)
        let encoder = RecordingRenderEncoder()
        renderer.frame = Frame(
            groundPlane: .init(isVisible: true),
            wireBox: .init(
                isVisible: true,
                center: .zero,
                size: .init(repeating: 10)
            ),
            cameraFrustum: .init(isVisible: true)
        )

        try renderer.prepare()
        renderer.encodeBackground(into: encoder)
        renderer.encodeOverlay(into: encoder)

        #expect(encoder.draws.count == 2)
        #expect(encoder.draws[0].instanceCount == 1)
        #expect(encoder.draws[1].instanceCount == 2)
        #expect(platform.sharedBufferCount == 2)
    }
}

private final class RecordingPlatform: Platform {
    private(set) var sharedBufferCount = 0

    func acquireFrame() {}
    func releaseFrame() {}
    func submit(_ commandBuffer: any CommandBuffer) {}

    func makeBuffer(length: Int, memory: BufferMemory) -> (any Buffer)? {
        RecordingBuffer(length: length)
    }

    func makeBuffer(sharing storage: HostBuffer) -> (any Buffer)? {
        sharedBufferCount += 1
        return RecordingBuffer(length: storage.allocatedByteCount)
    }

    func makeComputePipeline(function: String) -> (any ComputePipeline)? {
        RecordingComputePipeline()
    }

    func makeRenderPipeline(
        _ descriptor: RenderPipelineDescriptor
    ) -> (any RenderPipeline)? {
        RecordingRenderPipeline()
    }

    func makeDepthState(
        compare: CompareFunction,
        isWriteEnabled: Bool
    ) -> (any DepthState)? {
        RecordingDepthState()
    }

    func makeCommandBuffer() -> (any CommandBuffer)? { nil }
    func currentRenderTarget() -> (any RenderTarget)? { nil }
}

private final class RecordingBuffer: Buffer {
    let length: Int

    init(length: Int) { self.length = length }

    func withMutableBytes(
        _ body: (UnsafeMutableRawBufferPointer) -> Void
    ) {
        body(.init(start: nil, count: 0))
    }
}

private final class RecordingComputePipeline: ComputePipeline {}
private final class RecordingRenderPipeline: RenderPipeline {}
private final class RecordingDepthState: DepthState {}

private final class RecordingRenderEncoder: RenderEncoder {
    struct Draw {
        let vertexCount: Int
        let instanceCount: Int
    }

    var label: String?
    private(set) var draws: [Draw] = []

    func setPipeline(_ pipeline: any RenderPipeline) {}
    func setDepthState(_ state: any DepthState) {}
    func setVertexBuffer(_ buffer: any Buffer, index: Int) {}
    func setVertexBytes(_ bytes: UnsafeRawBufferPointer, index: Int) {}

    func drawPrimitives(
        _ primitive: Primitive,
        indirectBuffer: any Buffer
    ) {}

    func drawPrimitives(
        _ primitive: Primitive,
        vertexStart: Int,
        vertexCount: Int
    ) {
        draws.append(.init(vertexCount: vertexCount, instanceCount: 1))
    }

    func drawPrimitives(
        _ primitive: Primitive,
        vertexStart: Int,
        vertexCount: Int,
        instanceCount: Int
    ) {
        draws.append(.init(
            vertexCount: vertexCount,
            instanceCount: instanceCount
        ))
    }

    func endEncoding() {}
}

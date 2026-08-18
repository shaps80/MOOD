import Testing
@testable import PixlRenderer

@Suite("Frame buffers")
struct FrameBuffersTests {
    @Test("Shares particle storage and caps LOD output storage")
    func lodStorage() throws {
        let platform = RecordingPlatform()
        let buffers = FrameBuffers(platform: platform, frameCount: 2)
        let source = PointBuffers(
            previousPositions: .init(byteCount: 150 * 48),
            currentPositions: .init(byteCount: 150 * 48),
            previousColors: .init(byteCount: 150 * 64),
            currentColors: .init(byteCount: 150 * 64),
            ids: .init(byteCount: 150 * 32)
        )

        _ = try buffers.prepare(
            count: 600,
            buffers: source,
            lod: .init(
                activationCount: 500,
                maximumVisibleCount: 200
            ),
            viewport: .init(width: 100, height: 100)
        )

        let visibleLength = 200 * MemoryLayout<UInt32>.stride
        #expect(platform.sharedBuffers.count == 5)
        #expect(
            platform.allocations.filter {
                $0.length == visibleLength && !$0.memory.isCPUVisible
            }.count == 2
        )
    }
}

private final class RecordingPlatform: Platform {
    struct Allocation {
        let length: Int
        let memory: BufferMemory
    }

    var allocations: [Allocation] = []
    var sharedBuffers: [HostBuffer] = []

    func acquireFrame() {}
    func releaseFrame() {}
    func submit(_ commandBuffer: any CommandBuffer) {}

    func makeBuffer(length: Int, memory: BufferMemory) -> (any Buffer)? {
        allocations.append(.init(length: length, memory: memory))
        return RecordingBuffer(length: length)
    }

    func makeBuffer(sharing storage: HostBuffer) -> (any Buffer)? {
        sharedBuffers.append(storage)
        return RecordingBuffer(length: storage.allocatedByteCount)
    }

    func makeComputePipeline(function: String) -> (any ComputePipeline)? { nil }
    func makeRenderPipeline(
        _ descriptor: RenderPipelineDescriptor
    ) -> (any RenderPipeline)? { nil }
    func makeDepthState(
        compare: CompareFunction,
        isWriteEnabled: Bool
    ) -> (any DepthState)? { nil }
    func makeCommandBuffer() -> (any CommandBuffer)? { nil }
    func currentRenderTarget() -> (any RenderTarget)? { nil }
}

private extension BufferMemory {
    var isCPUVisible: Bool {
        if case .cpuVisible = self { true } else { false }
    }
}

private final class RecordingBuffer: Buffer {
    let length: Int
    private let bytes: UnsafeMutableRawBufferPointer

    init(length: Int) {
        self.length = length
        bytes = .allocate(byteCount: length, alignment: 16)
    }

    deinit {
        bytes.deallocate()
    }

    func withMutableBytes(
        _ body: (UnsafeMutableRawBufferPointer) -> Void
    ) {
        body(bytes)
    }
}

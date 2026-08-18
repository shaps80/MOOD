import PixlRenderer
import Swift

final class WireVolumePass {
    private static let frameCount = 2
    private static let vertexCount = 24
    private static let capacity = 2

    private struct Instance: BitwiseCopyable {
        let transform: Matrix4x4
        let color: SIMD4<Float>
    }

    private struct Slot {
        let host: HostBuffer
        let device: any Buffer
    }

    private let pipeline: any RenderPipeline
    private let depth: any DepthState
    private let slots: [Slot]
    private var nextSlot = 0
    private var preparedSlot = 0
    private var instanceCount = 0

    init(platform: any Platform) throws {
        guard let pipeline = platform.makeRenderPipeline(
            .init(
                vertexFunction: "editorWireVolumeVertex",
                fragmentFunction: "editorWireVolumeFragment",
                colorFormat: .rgba16Float,
                depthFormat: .depth32Float,
                blendMode: .premultiplied
            )
        ), let depth = platform.makeDepthState(
            compare: .less,
            isWriteEnabled: false
        ) else {
            throw EditorSupportError.pipeline
        }
        var slots: [Slot] = []
        slots.reserveCapacity(Self.frameCount)
        for _ in 0..<Self.frameCount {
            let host = HostBuffer(
                byteCount: MemoryLayout<Instance>.stride * Self.capacity
            )
            guard let device = platform.makeBuffer(sharing: host) else {
                throw EditorSupportError.buffer
            }
            host.bindMemory(to: Instance.self, count: Self.capacity)
                .initialize(repeating: .init(
                    transform: .identity,
                    color: .zero
                ))
            slots.append(.init(host: host, device: device))
        }
        self.pipeline = pipeline
        self.depth = depth
        self.slots = slots
    }

    func prepare(frame: Frame) {
        preparedSlot = nextSlot
        nextSlot = (nextSlot + 1) % slots.count
        let instances = slots[preparedSlot].host.mutableBuffer(
            of: Instance.self,
            count: Self.capacity
        )
        var count = 0
        if frame.wireBox.isVisible {
            instances[count] = Self.instance(for: frame.wireBox)
            count += 1
        }
        if frame.cameraFrustum.isVisible {
            instances[count] = .init(
                transform: frame.cameraFrustum.inverseViewProjection,
                color: [0.45, 0.015, 0.01, 0.55]
            )
            count += 1
        }
        instanceCount = count
    }

    func encode(
        viewProjection: Matrix4x4,
        into encoder: any RenderEncoder
    ) {
        guard instanceCount > 0 else { return }
        encoder.setPipeline(pipeline)
        encoder.setDepthState(depth)
        encoder.setVertexValue(viewProjection, index: 0)
        encoder.setVertexBuffer(slots[preparedSlot].device, index: 1)
        encoder.drawPrimitives(
            .line,
            vertexStart: 0,
            vertexCount: Self.vertexCount,
            instanceCount: instanceCount
        )
    }

    private static func instance(for box: WireBox) -> Instance {
        let half = box.size * 0.5
        return .init(
            transform: Matrix4x4(
                x: [half.x, 0, 0, 0],
                y: [0, half.y, 0, 0],
                z: [0, 0, box.size.z, 0],
                w: [box.center.x, box.center.y, box.center.z - half.z, 1]
            ),
            color: box.color
        )
    }
}

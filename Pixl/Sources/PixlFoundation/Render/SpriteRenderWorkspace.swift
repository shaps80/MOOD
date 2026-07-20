import PixlPlatform

private struct SpriteViewParameters: BitwiseCopyable {
    let x: SIMD3<Float>
    let y: SIMD3<Float>
    let translation: SIMD3<Float>
}

private struct WorkspaceMaterial {
    let resolved: ResolvedSpriteMaterial
    var pipelineFormat: PixelFormat?
    var pipeline: RenderPipeline?
}

/// Fixed-capacity sprite encoding storage paired with one render queue.
public final class SpriteRenderWorkspace {
    /// CPU duration produced while encoding one execution view.
    public struct Metrics: Hashable, Sendable {
        /// Seconds spent compacting visible instances into upload order.
        public let instancesSeconds: Double

        package init(instancesSeconds: Double = 0) {
            self.instancesSeconds = instancesSeconds
        }
    }

    private let resources: SpriteRenderResources
    private let queue: RenderQueue
    private let capacity: Int
    private let resolved: UnsafeMutablePointer<WorkspaceMaterial?>
    private let upload: UnsafeMutablePointer<RenderQueue.Instance>

    package init(resources: SpriteRenderResources, queue: RenderQueue) {
        self.resources = resources
        self.queue = queue
        let capacity = queue.settings.capacity
        self.capacity = capacity
        resolved = .allocate(capacity: capacity)
        resolved.initialize(repeating: nil, count: capacity)
        upload = .allocate(capacity: capacity)
        upload.initialize(
            repeating: RenderQueue.Instance(
                transformX: .zero,
                transformY: .zero,
                translation: .zero,
                textureOrigin: .zero,
                textureScale: .zero,
                tintRGBA8: 0
            ),
            count: capacity
        )
        precondition(
            MemoryLayout<RenderQueue.Instance>.stride == 48,
            "Sprite instance ABI must remain 48 bytes"
        )
    }

    deinit {
        resolved.deinitialize(count: capacity)
        resolved.deallocate()
        upload.deinitialize(count: capacity)
        upload.deallocate()
    }

    /// Encodes one execution view using shared device resources.
    ///
    /// The execution must come from the queue passed to
    /// ``SpriteRenderResources/makeWorkspace(for:)``. The workspace retains
    /// fixed-capacity material-slot and upload storage between calls.
    public func encode(
        _ execution: RenderQueue.Execution,
        viewIndex: Int,
        on pass: RenderPassEncoder
    ) throws -> Metrics {
        precondition(
            execution.queue === queue,
            "Execution belongs to another render queue"
        )
        precondition(execution.instances.count <= capacity)
        precondition(execution.materials.count <= capacity)
        precondition(execution.views.indices.contains(viewIndex))
        let view = execution.views[viewIndex]
        guard !view.ordinals.isEmpty else { return Metrics() }
        let geometry = try resources.geometry()

        let instanceStart = ContinuousClock.now
        for index in view.ordinals.indices {
            upload[index] = execution.instances[Int(view.ordinals[index])]
        }
        pass.setVertexBuffer(geometry.vertex, index: 0)
        pass.setVertexBytes(
            of: SpriteViewParameters(
                x: view.projectionX,
                y: view.projectionY,
                translation: view.projectionTranslation
            ),
            index: 2
        )
        pass.setVertexData(
            UnsafeRawBufferPointer(
                start: upload,
                count: view.ordinals.count
                    * MemoryLayout<RenderQueue.Instance>.stride
            ),
            index: 1
        )
        let metrics = Metrics(instancesSeconds: Self.seconds(since: instanceStart))

        var start = UInt32(0)
        for batch in view.batches {
            let materialIndex = Int(batch.material)
            var material = try resolve(
                execution.materials[materialIndex],
                at: materialIndex
            )
            if material.pipelineFormat != pass.colorFormat {
                material.pipeline = try resources.pipeline(
                    format: pass.colorFormat,
                    blendMode: execution.materials[materialIndex].blendMode
                )
                material.pipelineFormat = pass.colorFormat
                resolved[materialIndex] = material
            }
            pass.setRenderPipeline(material.pipeline!)
            pass.setFragmentTexture(material.resolved.texture, index: 0)
            pass.setFragmentSampler(material.resolved.sampler, index: 0)
            pass.drawIndexedPrimitives(
                .triangle,
                indexCount: 6,
                indexType: .uint16,
                indexBuffer: geometry.index,
                instanceCount: batch.end - start,
                baseInstance: start
            )
            start = batch.end
        }
        return metrics
    }

    private func resolve(
        _ source: RenderQueue.Material,
        at index: Int
    ) throws -> WorkspaceMaterial {
        if let value = resolved[index] { return value }
        let value = WorkspaceMaterial(
            resolved: try resources.resolve(source),
            pipelineFormat: nil,
            pipeline: nil
        )
        resolved[index] = value
        return value
    }

    private static func seconds(since start: ContinuousClock.Instant) -> Double {
        let value = (ContinuousClock.now - start).components
        return Double(value.seconds) + Double(value.attoseconds) * 1e-18
    }
}

import PixlPlatform

private struct SpriteViewParameters: BitwiseCopyable {
    let x: SIMD3<Float>
    let y: SIMD3<Float>
    let translation: SIMD3<Float>
    /// Logical presentation dimensions stored in the first trailing uniform slot.
    let logicalSize: SIMD2<Float>
    /// Reserved trailing uniform slot. Keeps the shared Metal/WGSL view ABI at
    /// 64 bytes; future view data may use this space without growing the buffer.
    let padding: SIMD2<Float> = .zero
}

private struct WorkspaceSpriteResources {
    let resolved: ResolvedSpriteResources
    var pipelineFormat: PixelFormat?
    var pipeline: RenderPipeline?
}

/// Fixed-capacity sprite and analytic-shape encoding storage paired with one render queue.
///
/// A workspace retains its queue and shared rendering resources. It does not
/// reset the queue after encoding. Logical textures cached by an encoded
/// material slot must remain live; backend-managed in-place texture writes do
/// not invalidate the slot.
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
    private let resolved: UnsafeMutablePointer<WorkspaceSpriteResources?>
    private let resolvedPolygonGeometry: UnsafeMutablePointer<PolygonGeometryResources?>
    private let upload: UnsafeMutablePointer<RenderQueue.Instance>
    private let shapeUpload: UnsafeMutablePointer<RenderQueue.ShapeInstance>
    private let extendedShapeUpload: UnsafeMutablePointer<RenderQueue.ExtendedShapeInstance>
    private let primitiveUpload: UnsafeMutablePointer<RenderQueue.PrimitiveInstance>
    private let polygonUpload: UnsafeMutablePointer<RenderQueue.PolygonInstance>

    package init(resources: SpriteRenderResources, queue: RenderQueue) {
        self.resources = resources
        self.queue = queue
        let capacity = queue.settings.capacity
        self.capacity = capacity
        resolved = .allocate(capacity: capacity)
        resolved.initialize(repeating: nil, count: capacity)
        resolvedPolygonGeometry = .allocate(capacity: capacity)
        resolvedPolygonGeometry.initialize(repeating: nil, count: capacity)
        upload = .allocate(capacity: capacity)
        upload.initialize(
            repeating: RenderQueue.Instance(
                transformX: .zero,
                transformY: .zero,
                translation: .zero,
                textureOrigin: .zero,
                textureScale: .zero,
                tintRGBA8: 0,
                modulationMode: 0
            ),
            count: capacity
        )
        shapeUpload = .allocate(capacity: capacity)
        shapeUpload.initialize(repeating: .init(
            transformX: .zero, transformY: .zero, translation: .zero,
            quadHalfExtent: .zero,
            parameters: .zero, fillColor: .zero, strokeColor: .zero, style: .zero
        ), count: capacity)
        extendedShapeUpload = .allocate(capacity: capacity)
        extendedShapeUpload.initialize(repeating: .init(
            transformX: .zero, transformY: .zero, translation: .zero,
            quadHalfExtent: .zero,
            parameters: .zero, extendedParameters: .zero,
            fillColor: .zero, strokeColor: .zero, style: .zero
        ), count: capacity)
        primitiveUpload = .allocate(capacity: capacity)
        primitiveUpload.initialize(repeating: .init(
            transformX: .zero, transformY: .zero, translation: .zero,
            origin: .zero, size: .zero, width: 0, colorRGBA8: 0
        ), count: capacity)
        polygonUpload = .allocate(capacity: capacity)
        polygonUpload.initialize(repeating: .init(
            transformX: .zero,
            transformY: .zero,
            translation: .zero,
            colorRGBA8: 0
        ), count: capacity)
        precondition(
            MemoryLayout<RenderQueue.Instance>.stride == 48,
            "Sprite instance ABI must remain 48 bytes"
        )
        precondition(
            MemoryLayout<RenderQueue.PolygonInstance>.stride == 32,
            "Polygon instance ABI must remain 32 bytes"
        )
    }

    deinit {
        resolved.deinitialize(count: capacity)
        resolved.deallocate()
        resolvedPolygonGeometry.deinitialize(count: capacity)
        resolvedPolygonGeometry.deallocate()
        upload.deinitialize(count: capacity)
        upload.deallocate()
        shapeUpload.deinitialize(count: capacity)
        shapeUpload.deallocate()
        extendedShapeUpload.deinitialize(count: capacity)
        extendedShapeUpload.deallocate()
        primitiveUpload.deinitialize(count: capacity)
        primitiveUpload.deallocate()
        polygonUpload.deinitialize(count: capacity)
        polygonUpload.deallocate()
    }

    /// Encodes one execution view using shared sprite rendering resources.
    ///
    /// The execution must come from the queue passed to
    /// ``SpriteRenderResources/makeWorkspace(for:)``. The workspace retains
    /// fixed-capacity material-slot and upload storage between calls.
    ///
    /// - Parameters:
    ///   - execution: Transient execution produced by the paired queue.
    ///   - viewIndex: Valid zero-based view to encode from `execution`.
    ///   - pass: Render-pass encoder receiving sprite commands. Its colour
    ///     format selects the compatible pipeline variant.
    /// - Returns: CPU timing for work performed by this encoding step.
    /// - Throws: A device-resource creation or command-recording error.
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
        precondition(execution.spriteBatchKeys.count <= capacity)
        precondition(execution.views.indices.contains(viewIndex))
        let view = execution.views[viewIndex]
        guard !view.ordinals.isEmpty else { return Metrics() }
        let geometry = try resources.geometry()
        var hasSprites = false
        var hasShapes = false
        var hasExtendedShapes = false
        var hasPrimitives = false
        var hasPolygons = false
        var hasGradients = false
        for batch in view.batches {
            switch batch.family {
            case .sprite: hasSprites = true
            case .shape: hasShapes = true
            case .extendedShape: hasExtendedShapes = true
            case .primitive: hasPrimitives = true
            case .polygon: hasPolygons = true
            }
            if (batch.family == .shape || batch.family == .extendedShape),
                execution.shapeBatchKeys[Int(batch.key)].usesGradient
            {
                hasGradients = true
            }
        }

        let instanceStart = ContinuousClock.now
        for index in view.ordinals.indices {
            let ordinal = Int(view.ordinals[index])
            if hasSprites { upload[index] = execution.instances[ordinal] }
            if hasShapes { shapeUpload[index] = execution.shapeInstances[ordinal] }
            if hasExtendedShapes {
                extendedShapeUpload[index] = execution.extendedShapeInstances[ordinal]
            }
            if hasPrimitives {
                primitiveUpload[index] = execution.primitiveInstances[ordinal]
            }
            if hasPolygons {
                polygonUpload[index] = execution.polygonInstances[ordinal]
            }
        }
        pass.setVertexBuffer(geometry.vertex, index: 0)
        pass.setVertexBytes(
            of: SpriteViewParameters(
                x: view.projectionX,
                y: view.projectionY,
                translation: view.projectionTranslation,
                logicalSize: view.logicalSize
            ),
            index: 2
        )
        if hasSprites {
            pass.setVertexData(
                UnsafeRawBufferPointer(
                    start: upload,
                    count: view.ordinals.count
                        * MemoryLayout<RenderQueue.Instance>.stride
                ),
                index: 1
            )
        }
        if hasShapes {
            pass.setVertexData(
                UnsafeRawBufferPointer(
                    start: shapeUpload,
                    count: view.ordinals.count
                        * MemoryLayout<RenderQueue.ShapeInstance>.stride
                ),
                index: 3
            )
        }
        if hasExtendedShapes {
            pass.setVertexData(
                UnsafeRawBufferPointer(
                    start: extendedShapeUpload,
                    count: view.ordinals.count
                        * MemoryLayout<RenderQueue.ExtendedShapeInstance>.stride
                ),
                index: 4
            )
        }
        if hasPrimitives {
            pass.setVertexData(
                UnsafeRawBufferPointer(
                    start: primitiveUpload,
                    count: view.ordinals.count
                        * MemoryLayout<RenderQueue.PrimitiveInstance>.stride
                ),
                index: 5
            )
        }
        if hasPolygons {
            pass.setVertexData(
                UnsafeRawBufferPointer(
                    start: polygonUpload,
                    count: view.ordinals.count
                        * MemoryLayout<RenderQueue.PolygonInstance>.stride
                ),
                index: 6
            )
        }
        let metrics = Metrics(instancesSeconds: Self.seconds(since: instanceStart))
        let gradients = try hasGradients ? resources.gradientResources(for: execution) : nil

        var start = UInt32(0)
        var usesSharedGeometry = true
        var usesPrimitiveGeometry = false
        var primitiveGeometry: PrimitiveGeometryResources?
        for batch in view.batches {
            switch batch.family {
            case .sprite:
                if !usesSharedGeometry {
                    pass.setVertexBuffer(geometry.vertex, index: 0)
                    usesSharedGeometry = true
                    usesPrimitiveGeometry = false
                }
                let keyIndex = Int(batch.key)
                var spriteResources = try resolve(
                    execution.spriteBatchKeys[keyIndex], at: keyIndex
                )
                if spriteResources.pipelineFormat != pass.colorFormat {
                    spriteResources.pipeline = try resources.pipeline(
                        format: pass.colorFormat,
                        blendMode: execution.spriteBatchKeys[keyIndex].blendMode
                    )
                    spriteResources.pipelineFormat = pass.colorFormat
                    resolved[keyIndex] = spriteResources
                }
                pass.setRenderPipeline(spriteResources.pipeline!)
                pass.setFragmentTexture(spriteResources.resolved.texture, index: 0)
                pass.setFragmentSampler(spriteResources.resolved.sampler, index: 0)
            case .shape:
                if !usesSharedGeometry {
                    pass.setVertexBuffer(geometry.vertex, index: 0)
                    usesSharedGeometry = true
                    usesPrimitiveGeometry = false
                }
                let key = execution.shapeBatchKeys[Int(batch.key)]
                pass.setRenderPipeline(try resources.shapePipeline(
                    format: pass.colorFormat,
                    blendMode: key.blendMode,
                    usesGradient: key.usesGradient
                ))
                if key.usesGradient {
                    pass.setFragmentTexture(gradients!.texture, index: 1)
                    pass.setFragmentSampler(gradients!.sampler, index: 1)
                }
            case .extendedShape:
                if !usesSharedGeometry {
                    pass.setVertexBuffer(geometry.vertex, index: 0)
                    usesSharedGeometry = true
                    usesPrimitiveGeometry = false
                }
                let key = execution.shapeBatchKeys[Int(batch.key)]
                pass.setRenderPipeline(try resources.extendedShapePipeline(
                    format: pass.colorFormat,
                    blendMode: key.blendMode,
                    usesGradient: key.usesGradient
                ))
                if key.usesGradient {
                    pass.setFragmentTexture(gradients!.texture, index: 1)
                    pass.setFragmentSampler(gradients!.sampler, index: 1)
                }
            case .primitive:
                let primitive = try primitiveGeometry ?? resources.primitiveGeometry()
                primitiveGeometry = primitive
                if !usesPrimitiveGeometry {
                    pass.setVertexBuffer(primitive.vertex, index: 0)
                    usesSharedGeometry = false
                    usesPrimitiveGeometry = true
                }
                pass.setRenderPipeline(try resources.primitivePipeline(format: pass.colorFormat))
                let range = primitive.ranges[Int(batch.key)]
                pass.drawIndexedPrimitives(
                    .triangle,
                    indexCount: range.indexCount,
                    indexType: .uint16,
                    indexBuffer: primitive.index,
                    indexBufferOffset: range.indexBufferOffset,
                    instanceCount: batch.end - start,
                    baseVertex: range.baseVertex,
                    baseInstance: start
                )
                start = batch.end
                continue
            case .polygon:
                let key = execution.polygonBatchKeys[Int(batch.key)]
                let geometryIndex = Int(key.geometry)
                let polygon = try resolvePolygonGeometry(
                    execution.polygonGeometries[geometryIndex],
                    at: geometryIndex
                )
                pass.setVertexBuffer(polygon.vertex, index: 0)
                usesSharedGeometry = false
                usesPrimitiveGeometry = false
                pass.setRenderPipeline(try resources.polygonPipeline(
                    format: pass.colorFormat,
                    blendMode: key.blendMode
                ))
                pass.drawIndexedPrimitives(
                    .triangle,
                    indexCount: polygon.indexCount,
                    indexType: .uint32,
                    indexBuffer: polygon.index,
                    instanceCount: batch.end - start,
                    baseInstance: start
                )
                start = batch.end
                continue
            }
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
        _ source: RenderQueue.SpriteBatchKey,
        at index: Int
    ) throws -> WorkspaceSpriteResources {
        if let value = resolved[index] { return value }
        let value = WorkspaceSpriteResources(
            resolved: try resources.resolve(source),
            pipelineFormat: nil,
            pipeline: nil
        )
        resolved[index] = value
        return value
    }

    private func resolvePolygonGeometry(
        _ source: RenderQueue.PolygonGeometry,
        at index: Int
    ) throws -> PolygonGeometryResources {
        if let value = resolvedPolygonGeometry[index] { return value }
        let value = try resources.polygonGeometry(source)
        resolvedPolygonGeometry[index] = value
        return value
    }

    private static func seconds(since start: ContinuousClock.Instant) -> Double {
        let value = (ContinuousClock.now - start).components
        return Double(value.seconds) + Double(value.attoseconds) * 1e-18
    }
}

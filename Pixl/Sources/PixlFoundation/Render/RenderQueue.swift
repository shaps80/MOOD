import PixlPlatform
import Swift

/// Fixed-capacity retained submission and CPU execution storage.
///
/// `execute(views:_:)` lends transient execution buffers only for the duration
/// of its closure. Direct Foundation users reset explicitly; Pixl's
/// `GameContext` convenience resets its default queue automatically.
public final class RenderQueue {
    package enum Submission {
        case sprite(SpriteSubmission)
        case shape(ShapeSubmission)
        case primitive(PrimitiveSubmission)
    }

    /// GPU renderer family for one consecutive batch.
    public enum Family: UInt32, BitwiseCopyable, Sendable {
        /// Texture-sampled sprite instances.
        case sprite
        /// Analytic signed-distance shape instances.
        case shape
        /// Point-defined analytic signed-distance shape instances.
        case extendedShape
        /// Lightweight filled or stroked immediate primitives.
        case primitive
    }
    /// Fixed capacities allocated by a render queue.
    public struct Settings: Hashable, Sendable {
        /// Maximum number of submissions retained between resets.
        public var capacity: Int
        /// Maximum number of views processed by one execution. Defaults to `1`.
        public var viewCapacity: Int
        /// Maximum distinct retained gradient ramps. Defaults to `256`.
        public var gradientCapacity: Int

        /// Creates fixed queue capacities.
        /// - Parameters:
        ///   - capacity: Positive maximum submission count.
        ///   - viewCapacity: Maximum simultaneous views in `1...64`.
        ///   - gradientCapacity: Maximum distinct retained gradient ramps in `1...256`.
        public init(
            capacity: Int = 10_000,
            viewCapacity: Int = 1,
            gradientCapacity: Int = 256
        ) {
            precondition(capacity > 0)
            precondition(UInt64(capacity) <= UInt64(UInt32.max))
            precondition(capacity <= Int.max / 2)
            precondition(UInt64(capacity) < UInt64(1) << 30)
            precondition((1...64).contains(viewCapacity))
            precondition((1...256).contains(gradientCapacity))
            self.capacity = capacity
            self.viewCapacity = viewCapacity
            self.gradientCapacity = gradientCapacity
        }
    }

    /// CPU duration of each stage in the latest queue execution.
    public struct Metrics: Hashable, Sendable {
        /// Seconds spent lowering retained submissions into execution streams.
        public var loweringSeconds = 0.0
        /// Seconds spent testing submission bounds against views.
        public var cullingSeconds = 0.0
        /// Seconds spent compressing visible render layers.
        public var layerBinningSeconds = 0.0
        /// Seconds spent ordering visible submissions.
        public var orderingSeconds = 0.0
        /// Seconds spent forming consecutive compatible batches.
        public var batchingSeconds = 0.0
        /// Seconds spent preparing view-local instance data.
        public var instancesSeconds = 0.0

        /// Creates zeroed execution metrics.
        public init() {}
    }

    /// Projection and world-space visibility bounds for one render view.
    public struct View: Sendable {
        /// First column of the world-to-clip affine transform.
        public let projectionX: SIMD3<Float>
        /// Second column of the world-to-clip affine transform.
        public let projectionY: SIMD3<Float>
        /// Translation column of the world-to-clip affine transform.
        public let projectionTranslation: SIMD3<Float>
        /// Logical presentation dimensions used for screen-constant geometry.
        public let logicalSize: SIMD2<Float>
        /// Inclusive world-space minimum used for visibility tests.
        public let boundsMinimum: SIMD2<Float>
        /// Inclusive world-space maximum used for visibility tests.
        public let boundsMaximum: SIMD2<Float>

        /// Creates one execution view.
        /// - Parameters:
        ///   - projectionX: First world-to-clip transform column.
        ///   - projectionY: Second world-to-clip transform column.
        ///   - projectionTranslation: World-to-clip translation column.
        ///   - boundsMinimum: World-space visibility minimum.
        ///   - boundsMaximum: World-space visibility maximum.
        public init(
            projectionX: SIMD3<Float>,
            projectionY: SIMD3<Float>,
            projectionTranslation: SIMD3<Float>,
            logicalSize: SIMD2<Float>,
            boundsMinimum: SIMD2<Float>,
            boundsMaximum: SIMD2<Float>
        ) {
            self.projectionX = projectionX
            self.projectionY = projectionY
            self.projectionTranslation = projectionTranslation
            precondition(logicalSize.x > 0 && logicalSize.y > 0)
            self.logicalSize = logicalSize
            self.boundsMinimum = boundsMinimum
            self.boundsMaximum = boundsMaximum
        }
    }

    /// Compact 48-byte GPU-facing sprite instance produced during lowering.
    public struct Instance: BitwiseCopyable, Sendable {
        /// First scaled model-transform column.
        public let transformX: SIMD2<Float>
        /// Second scaled model-transform column.
        public let transformY: SIMD2<Float>
        /// Model-transform translation.
        public let translation: SIMD2<Float>
        /// Normalized texture-coordinate origin.
        public let textureOrigin: SIMD2<Float>
        /// Normalized texture-coordinate scale.
        public let textureScale: SIMD2<Float>
        /// Packed eight-bit RGBA tint.
        public let tintRGBA8: UInt32
        /// Packed modulation behaviour and texture-alpha representation.
        public let modulationMode: UInt32
    }

    /// Compact GPU-facing analytic-shape instance produced during lowering.
    public struct ShapeInstance: BitwiseCopyable, Sendable {
        /// First scaled model-transform column.
        public let transformX: SIMD2<Float>
        /// Second scaled model-transform column.
        public let transformY: SIMD2<Float>
        /// Model-transform translation.
        public let translation: SIMD2<Float>
        /// Local quad half extent, including outward stroke.
        public let quadHalfExtent: SIMD2<Float>
        /// Formula-specific local parameters.
        public let parameters: SIMD4<Float>
        /// Premultiplied interior colour.
        public let fillColor: SIMD4<Float>
        /// Premultiplied stroke colour.
        public let strokeColor: SIMD4<Float>
        /// Packed formula, stroke, alignment/antialiasing, and rounding values.
        public let style: SIMD4<Float>
    }

    /// GPU-facing point-defined analytic-shape instance produced during lowering.
    public struct ExtendedShapeInstance: BitwiseCopyable, Sendable {
        /// First scaled model-transform column.
        public let transformX: SIMD2<Float>
        /// Second scaled model-transform column.
        public let transformY: SIMD2<Float>
        /// Model-transform translation.
        public let translation: SIMD2<Float>
        /// Local quad half extent, including outward stroke.
        public let quadHalfExtent: SIMD2<Float>
        /// First formula-specific parameter block.
        public let parameters: SIMD4<Float>
        /// Second formula-specific parameter block.
        public let extendedParameters: SIMD4<Float>
        /// Premultiplied interior colour.
        public let fillColor: SIMD4<Float>
        /// Premultiplied stroke colour.
        public let strokeColor: SIMD4<Float>
        /// Packed formula, stroke, alignment/antialiasing, and rounding values.
        public let style: SIMD4<Float>
    }

    /// Compact GPU-facing immediate-primitive instance produced during lowering.
    public struct PrimitiveInstance: BitwiseCopyable, Sendable {
        public let transformX: SIMD2<Float>
        public let transformY: SIMD2<Float>
        public let translation: SIMD2<Float>
        public let origin: SIMD2<Float>
        public let size: SIMD2<Float>
        /// Stroke width in logical screen units, or zero for a fill.
        public let width: Float
        /// Packed premultiplied linear eight-bit RGBA colour.
        public let colorRGBA8: UInt32
    }

    /// Shape pipeline compatibility shared by consecutive instances.
    package struct ShapeBatchKey: Hashable, Sendable {
        /// Fixed-function colour composition.
        public let blendMode: BlendMode
        /// Whether the fragment stage samples the shared gradient atlas.
        public let usesGradient: Bool
    }

    /// Sprite resource and pipeline compatibility shared by consecutive instances.
    package struct SpriteBatchKey: Hashable, Sendable {
        /// Logical texture identity.
        public let texture: TextureResourceID
        /// Complete sampling state.
        public let sampler: SamplerDescriptor
        /// Fixed-function colour composition.
        public let blendMode: BlendMode
    }

    /// One consecutive range sharing a batch key.
    public struct Batch: BitwiseCopyable, Sendable {
        /// Renderer family consuming this batch.
        public let family: Family
        /// Family-specific batch key index.
        public let key: UInt32
        /// Exclusive end offset in the view's ordinal stream.
        public let end: UInt32
    }

    /// Ordered visible submissions and batches for one view.
    public struct ViewOutput {
        /// First world-to-clip transform column.
        public let projectionX: SIMD3<Float>
        /// Second world-to-clip transform column.
        public let projectionY: SIMD3<Float>
        /// World-to-clip translation column.
        public let projectionTranslation: SIMD3<Float>
        /// Logical presentation dimensions used for screen-constant geometry.
        public let logicalSize: SIMD2<Float>
        /// Ordered indices into ``Execution/instances``.
        public let ordinals: UnsafeBufferPointer<UInt32>
        /// Consecutive compatible ranges over ``ordinals``.
        public let batches: UnsafeBufferPointer<Batch>
    }

    /// Transient read-only execution streams lent to an execution closure.
    public struct Execution {
        package let queue: RenderQueue
        /// Ordinal-aligned lowered instance records.
        public let instances: UnsafeBufferPointer<Instance>
        /// Ordinal-aligned analytic-shape instance records.
        public let shapeInstances: UnsafeBufferPointer<ShapeInstance>
        /// Ordinal-aligned point-defined shape instance records.
        public let extendedShapeInstances: UnsafeBufferPointer<ExtendedShapeInstance>
        /// Ordinal-aligned immediate-primitive instance records.
        public let primitiveInstances: UnsafeBufferPointer<PrimitiveInstance>
        /// Premultiplied RGBA8 rows for registered gradients.
        public let gradientAtlas: UnsafeBufferPointer<UInt8>
        /// Number of valid 256-pixel rows in ``gradientAtlas``.
        public let gradientCount: Int
        /// Monotonic atlas-content generation.
        public let gradientGeneration: UInt64
        /// Unique sprite batch keys referenced by view batches.
        package let spriteBatchKeys: UnsafeBufferPointer<SpriteBatchKey>
        /// Unique shape batch keys referenced by view batches.
        package let shapeBatchKeys: UnsafeBufferPointer<ShapeBatchKey>
        /// Outputs corresponding positionally to the supplied views.
        public let views: UnsafeBufferPointer<ViewOutput>
        /// CPU stage durations for this execution.
        public let metrics: Metrics
    }

    private struct OrderingRecord {
        let layer: UInt32
        let order: UInt32
        let layerSlot: UInt32
    }

    private struct LayerBin {
        var layer: UInt32
        var firstOrder: UInt32
        var count: Int
        var offset: Int
        var cursor: Int
        var varyingOrderBits: UInt32
        var generation: UInt32
    }

    private struct RegistryEntry {
        var value: UInt64
        var slot: UInt32
        var occupied: Bool
        static let empty = Self(value: 0, slot: 0, occupied: false)
    }

    private struct BatchState {
        var previousKey = UInt32(0)
        var visibleCount = UInt32(0)
        var batchCount = UInt32(0)
        var hasPrevious = false
    }

    private struct ViewContext {
        let ordinals: UnsafeMutablePointer<UInt32>
        let batches: UnsafeMutablePointer<Batch>
        var state: BatchState
    }

    /// Capacities allocated by this queue.
    public let settings: Settings
    /// Number of submissions currently retained.
    public private(set) var count = 0
    /// CPU stage durations from the most recent execution.
    public private(set) var latestMetrics = Metrics()

    private let submissions: UnsafeMutablePointer<Submission>
    private let boundsMinimum: UnsafeMutablePointer<SIMD2<Float>>
    private let boundsMaximum: UnsafeMutablePointer<SIMD2<Float>>
    private let orderingRecords: UnsafeMutablePointer<OrderingRecord>
    private let encodedBatchKeys: UnsafeMutablePointer<UInt32>
    private let instances: UnsafeMutablePointer<Instance>
    private let shapeInstances: UnsafeMutablePointer<ShapeInstance>
    private let extendedShapeInstances: UnsafeMutablePointer<ExtendedShapeInstance>
    private let primitiveInstances: UnsafeMutablePointer<PrimitiveInstance>
    private let families: UnsafeMutablePointer<Family>
    private let visibilityMasks: UnsafeMutablePointer<UInt64>
    private let visibleUnion: UnsafeMutablePointer<UInt32>
    private let orderedKeys: UnsafeMutablePointer<UInt64>
    private let orderingScratch: UnsafeMutablePointer<UInt64>
    private let layerBins: UnsafeMutablePointer<LayerBin>
    private let activeLayerSlots: UnsafeMutablePointer<UInt32>
    private let layerRegistry: UnsafeMutablePointer<RegistryEntry>
    private let spriteBatchKeyRegistry: UnsafeMutablePointer<RegistryEntry>
    private let spriteBatchKeys: UnsafeMutablePointer<SpriteBatchKey>
    private let shapeBatchKeys: UnsafeMutablePointer<ShapeBatchKey>
    private let radixCounts: UnsafeMutablePointer<Int>
    private let viewContexts: UnsafeMutablePointer<ViewContext>
    private let viewOutputs: UnsafeMutablePointer<ViewOutput>
    private let gradientFingerprints: UnsafeMutablePointer<UInt64>
    private let gradientIdentities: UnsafeMutablePointer<AnyObject?>
    private let gradientBytes: UnsafeMutablePointer<UInt8>
    private let registryCapacity: Int
    private var initializedExecutionCount = 0
    private var layerCount = 0
    private var spriteBatchKeyCount = 0
    private var shapeBatchKeyCount = 0
    private var layerGeneration = UInt32(0)
    private var gradientCount = 0
    private var gradientGeneration = UInt64(0)
    private var lastGradientIdentity: AnyObject?
    private var lastGradientSlot = UInt32.max

    /// Allocates all retained submission and execution storage.
    /// - Parameter settings: Fixed submission and view capacities.
    public init(settings: Settings = .init()) {
        self.settings = settings
        let capacity = settings.capacity
        registryCapacity = Self.registryCapacity(for: capacity)
        submissions = .allocate(capacity: capacity)
        boundsMinimum = .allocate(capacity: capacity)
        boundsMaximum = .allocate(capacity: capacity)
        orderingRecords = .allocate(capacity: capacity)
        encodedBatchKeys = .allocate(capacity: capacity)
        instances = .allocate(capacity: capacity)
        shapeInstances = .allocate(capacity: capacity)
        extendedShapeInstances = .allocate(capacity: capacity)
        primitiveInstances = .allocate(capacity: capacity)
        families = .allocate(capacity: capacity)
        visibilityMasks = .allocate(capacity: capacity)
        visibleUnion = .allocate(capacity: capacity)
        orderedKeys = .allocate(capacity: capacity)
        orderingScratch = .allocate(capacity: capacity)
        layerBins = .allocate(capacity: capacity)
        activeLayerSlots = .allocate(capacity: capacity)
        layerRegistry = .allocate(capacity: registryCapacity)
        spriteBatchKeyRegistry = .allocate(capacity: registryCapacity)
        spriteBatchKeys = .allocate(capacity: capacity)
        shapeBatchKeys = .allocate(capacity: capacity)
        radixCounts = .allocate(capacity: 256)
        viewContexts = .allocate(capacity: settings.viewCapacity)
        viewOutputs = .allocate(capacity: settings.viewCapacity)
        gradientFingerprints = .allocate(capacity: settings.gradientCapacity)
        gradientIdentities = .allocate(capacity: settings.gradientCapacity)
        gradientBytes = .allocate(capacity: settings.gradientCapacity * 256 * 4)
        gradientFingerprints.initialize(repeating: 0, count: settings.gradientCapacity)
        gradientIdentities.initialize(repeating: nil, count: settings.gradientCapacity)
        gradientBytes.initialize(repeating: 0, count: settings.gradientCapacity * 256 * 4)

        visibilityMasks.initialize(repeating: 0, count: capacity)
        visibleUnion.initialize(repeating: 0, count: capacity)
        orderedKeys.initialize(repeating: 0, count: capacity)
        orderingScratch.initialize(repeating: 0, count: capacity)
        activeLayerSlots.initialize(repeating: 0, count: capacity)
        layerRegistry.initialize(repeating: .empty, count: registryCapacity)
        spriteBatchKeyRegistry.initialize(repeating: .empty, count: registryCapacity)
        radixCounts.initialize(repeating: 0, count: 256)

        for index in 0..<settings.viewCapacity {
            let ordinals = UnsafeMutablePointer<UInt32>.allocate(capacity: capacity)
            let batches = UnsafeMutablePointer<Batch>.allocate(capacity: capacity)
            ordinals.initialize(repeating: 0, count: capacity)
            batches.initialize(repeating: Batch(family: .sprite, key: 0, end: 0), count: capacity)
            viewContexts.advanced(by: index).initialize(
                to: ViewContext(ordinals: ordinals, batches: batches, state: .init())
            )
        }
    }

    deinit {
        reset()
        submissions.deallocate()
        boundsMinimum.deinitialize(count: initializedExecutionCount)
        boundsMinimum.deallocate()
        boundsMaximum.deinitialize(count: initializedExecutionCount)
        boundsMaximum.deallocate()
        orderingRecords.deinitialize(count: initializedExecutionCount)
        orderingRecords.deallocate()
        encodedBatchKeys.deinitialize(count: initializedExecutionCount)
        encodedBatchKeys.deallocate()
        instances.deinitialize(count: initializedExecutionCount)
        instances.deallocate()
        shapeInstances.deinitialize(count: initializedExecutionCount)
        shapeInstances.deallocate()
        extendedShapeInstances.deinitialize(count: initializedExecutionCount)
        extendedShapeInstances.deallocate()
        primitiveInstances.deinitialize(count: initializedExecutionCount)
        primitiveInstances.deallocate()
        families.deinitialize(count: initializedExecutionCount)
        families.deallocate()
        visibilityMasks.deinitialize(count: settings.capacity)
        visibilityMasks.deallocate()
        visibleUnion.deinitialize(count: settings.capacity)
        visibleUnion.deallocate()
        orderedKeys.deinitialize(count: settings.capacity)
        orderedKeys.deallocate()
        orderingScratch.deinitialize(count: settings.capacity)
        orderingScratch.deallocate()
        layerBins.deinitialize(count: layerCount)
        layerBins.deallocate()
        activeLayerSlots.deinitialize(count: settings.capacity)
        activeLayerSlots.deallocate()
        layerRegistry.deinitialize(count: registryCapacity)
        layerRegistry.deallocate()
        spriteBatchKeyRegistry.deinitialize(count: registryCapacity)
        spriteBatchKeyRegistry.deallocate()
        spriteBatchKeys.deinitialize(count: spriteBatchKeyCount)
        spriteBatchKeys.deallocate()
        shapeBatchKeys.deinitialize(count: shapeBatchKeyCount)
        shapeBatchKeys.deallocate()
        radixCounts.deinitialize(count: 256)
        radixCounts.deallocate()
        for index in 0..<settings.viewCapacity {
            let context = viewContexts.advanced(by: index)
            context.pointee.ordinals.deinitialize(count: settings.capacity)
            context.pointee.ordinals.deallocate()
            context.pointee.batches.deinitialize(count: settings.capacity)
            context.pointee.batches.deallocate()
            context.deinitialize(count: 1)
        }
        viewContexts.deallocate()
        viewOutputs.deallocate()
        gradientFingerprints.deinitialize(count: settings.gradientCapacity)
        gradientFingerprints.deallocate()
        gradientIdentities.deinitialize(count: settings.gradientCapacity)
        gradientIdentities.deallocate()
        gradientBytes.deinitialize(count: settings.gradientCapacity * 256 * 4)
        gradientBytes.deallocate()
    }

    /// Removes every retained submission while preserving allocated storage and caches.
    public func reset() {
        submissions.deinitialize(count: count)
        count = 0
    }

    /// Appends one sprite submission and assigns its global submission ordinal.
    /// - Parameter submission: Camera-independent sprite snapshot to retain until reset.
    public func submit(_ submission: SpriteSubmission) {
        precondition(
            count < settings.capacity,
            "Render queue submission capacity exceeded: capacity \(settings.capacity), attempted count \(count + 1)"
        )
        submissions.advanced(by: count).initialize(to: .sprite(submission))
        count += 1
    }

    /// Appends one analytic-shape submission and assigns its global submission ordinal.
    /// - Parameter submission: Camera-independent shape snapshot retained until reset.
    public func submit(_ submission: ShapeSubmission) {
        precondition(
            count < settings.capacity,
            "Render queue submission capacity exceeded: capacity \(settings.capacity), attempted count \(count + 1)"
        )
        submissions.advanced(by: count).initialize(to: .shape(submission))
        count += 1
    }

    /// Appends one immediate primitive submission.
    public func submit(_ submission: PrimitiveSubmission) {
        precondition(
            count < settings.capacity,
            "Render queue submission capacity exceeded: capacity \(settings.capacity), attempted count \(count + 1)"
        )
        submissions.advanced(by: count).initialize(to: .primitive(submission))
        count += 1
    }

    /// Appends analytic-shape snapshots using one capacity check.
    package func submit(contentsOf submissions: UnsafeBufferPointer<ShapeSubmission>) {
        guard !submissions.isEmpty else { return }
        precondition(
            submissions.count <= settings.capacity - count,
            "Render queue submission capacity exceeded: capacity \(settings.capacity), attempted count \(count + submissions.count)"
        )
        var destination = self.submissions.advanced(by: count)
        for submission in submissions {
            destination.initialize(to: .shape(submission))
            destination = destination.advanced(by: 1)
        }
        count += submissions.count
    }

    /// Appends already-lowered mixed submissions using one capacity check.
    package func submit(contentsOf submissions: UnsafeBufferPointer<Submission>) {
        guard !submissions.isEmpty else { return }
        precondition(
            submissions.count <= settings.capacity - count,
            "Render queue submission capacity exceeded: capacity \(settings.capacity), attempted count \(count + submissions.count)"
        )
        self.submissions.advanced(by: count).initialize(
            from: submissions.baseAddress!,
            count: submissions.count
        )
        count += submissions.count
    }

    /// Registers one premultiplied 256-pixel RGBA8 gradient row.
    /// - Parameters:
    ///   - fingerprint: Stable content fingerprint used for cold-path lookup.
    ///   - rgba8: Exactly 1,024 premultiplied RGBA8 bytes.
    /// - Returns: Stable atlas row retained for this queue's lifetime.
    public func registerGradient(
        fingerprint: UInt64,
        rgba8: [UInt8]
    ) -> UInt32 {
        registerGradient(identity: nil, fingerprint: fingerprint, rgba8: rgba8)
    }

    package func registerGradient(
        identity: AnyObject,
        fingerprint: UInt64,
        rgba8: [UInt8]
    ) -> UInt32 {
        registerGradient(identity: Optional(identity), fingerprint: fingerprint, rgba8: rgba8)
    }

    private func registerGradient(
        identity: AnyObject?,
        fingerprint: UInt64,
        rgba8: [UInt8]
    ) -> UInt32 {
        precondition(rgba8.count == 256 * 4)
        if let identity, lastGradientIdentity === identity {
            return lastGradientSlot
        }
        if let identity {
            for slot in 0..<gradientCount where gradientIdentities[slot] === identity {
                lastGradientIdentity = identity
                lastGradientSlot = UInt32(slot)
                return UInt32(slot)
            }
        }
        for slot in 0..<gradientCount where gradientFingerprints[slot] == fingerprint {
            var matches = true
            let offset = slot * 256 * 4
            for index in rgba8.indices where gradientBytes[offset + index] != rgba8[index] {
                matches = false
                break
            }
            if matches {
                if let identity {
                    lastGradientIdentity = identity
                    lastGradientSlot = UInt32(slot)
                }
                return UInt32(slot)
            }
        }
        precondition(
            gradientCount < settings.gradientCapacity,
            "Render queue gradient capacity exceeded: capacity \(settings.gradientCapacity), attempted count \(gradientCount + 1)"
        )
        let slot = gradientCount
        gradientFingerprints[slot] = fingerprint
        gradientIdentities[slot] = identity
        let offset = slot * 256 * 4
        rgba8.withUnsafeBytes { source in
            gradientBytes.advanced(by: offset).update(
                from: source.bindMemory(to: UInt8.self).baseAddress!,
                count: rgba8.count
            )
        }
        gradientCount += 1
        gradientGeneration &+= 1
        if let identity {
            lastGradientIdentity = identity
            lastGradientSlot = UInt32(slot)
        }
        return UInt32(slot)
    }

    /// Culls, orders, and batches retained submissions for one or more views.
    ///
    /// Pointers in `Execution` are valid only during `body`. Execution does not
    /// reset the queue; direct Foundation callers control that lifecycle.
    ///
    /// - Parameters:
    ///   - views: Nonempty view buffer no larger than ``Settings/viewCapacity``.
    ///   - body: Closure consuming transient ordered execution streams.
    /// - Returns: The value returned by `body`.
    /// - Throws: Any error thrown by `body`.
    public func execute<Result>(
        views: UnsafeBufferPointer<View>,
        _ body: (Execution) throws -> Result
    ) rethrows -> Result {
        precondition(!views.isEmpty, "Render queue execution requires at least one view")
        precondition(
            views.count <= settings.viewCapacity,
            "Render queue view capacity exceeded: capacity \(settings.viewCapacity), attempted count \(views.count)"
        )
        var metrics = Metrics()
        let start = ContinuousClock.now
        lower()
        metrics.loweringSeconds = Self.seconds(since: start)

        let cullingStart = ContinuousClock.now
        let visibleCount = cull(views: views)
        metrics.cullingSeconds = Self.seconds(since: cullingStart)

        let binningStart = ContinuousClock.now
        let activeLayers = bin(visibleCount: visibleCount)
        metrics.layerBinningSeconds = Self.seconds(since: binningStart)

        let orderingStart = ContinuousClock.now
        order(visibleCount: visibleCount, activeLayerCount: activeLayers)
        metrics.orderingSeconds = Self.seconds(since: orderingStart)

        let batchingStart = ContinuousClock.now
        formBatches(visibleCount: visibleCount, viewCount: views.count)
        metrics.batchingSeconds = Self.seconds(since: batchingStart)

        let instanceStart = ContinuousClock.now
        for index in 0..<views.count {
            let context = viewContexts[index]
            viewOutputs.advanced(by: index).initialize(
                to: ViewOutput(
                    projectionX: views[index].projectionX,
                    projectionY: views[index].projectionY,
                    projectionTranslation: views[index].projectionTranslation,
                    logicalSize: views[index].logicalSize,
                    ordinals: UnsafeBufferPointer(
                        start: context.ordinals,
                        count: Int(context.state.visibleCount)
                    ),
                    batches: UnsafeBufferPointer(
                        start: context.batches,
                        count: Int(context.state.batchCount)
                    )
                )
            )
        }
        metrics.instancesSeconds = Self.seconds(since: instanceStart)
        latestMetrics = metrics
        defer { viewOutputs.deinitialize(count: views.count) }
        return try body(
            Execution(
                queue: self,
                instances: UnsafeBufferPointer(start: instances, count: count),
                shapeInstances: UnsafeBufferPointer(start: shapeInstances, count: count),
                extendedShapeInstances: UnsafeBufferPointer(start: extendedShapeInstances, count: count),
                primitiveInstances: UnsafeBufferPointer(start: primitiveInstances, count: count),
                gradientAtlas: UnsafeBufferPointer(
                    start: gradientBytes,
                    count: gradientCount * 256 * 4
                ),
                gradientCount: gradientCount,
                gradientGeneration: gradientGeneration,
                spriteBatchKeys: UnsafeBufferPointer(
                    start: spriteBatchKeys,
                    count: spriteBatchKeyCount
                ),
                shapeBatchKeys: UnsafeBufferPointer(
                    start: shapeBatchKeys,
                    count: shapeBatchKeyCount
                ),
                views: UnsafeBufferPointer(start: viewOutputs, count: views.count),
                metrics: metrics
            )
        )
    }

    private func lower() {
        for index in 0..<count {
            let source = submissions[index]
            let sourceLayer: UInt32
            let sourceOrder: UInt32
            let sourceBoundsMinimum: SIMD2<Float>
            let sourceBoundsMaximum: SIMD2<Float>
            let family: Family
            let encodedBatchKey: UInt32
            let spriteInstance: Instance
            let shapeInstance: ShapeInstance
            let extendedShapeInstance: ExtendedShapeInstance
            let primitiveInstance: PrimitiveInstance
            switch source {
            case .sprite(let source):
                let batchKey = SpriteBatchKey(
                    texture: source.texture,
                    sampler: source.sampler,
                    blendMode: source.blendMode
                )
                encodedBatchKey = resolveSpriteBatchKey(batchKey)
                family = .sprite
                sourceLayer = source.layer
                sourceOrder = source.order
                sourceBoundsMinimum = source.boundsMinimum
                sourceBoundsMaximum = source.boundsMaximum
                spriteInstance = Instance(
                    transformX: source.transformX,
                    transformY: source.transformY,
                    translation: source.transformTranslation,
                    textureOrigin: source.textureCoordinateOrigin,
                    textureScale: source.textureCoordinateScale,
                    tintRGBA8: source.tintRGBA8,
                    modulationMode: source.modulationMode
                )
                shapeInstance = Self.emptyShapeInstance
                extendedShapeInstance = Self.emptyExtendedShapeInstance
                primitiveInstance = Self.emptyPrimitiveInstance
            case .shape(let source):
                let isExtended = source.kind == .triangle
                    || source.kind == .quadraticBezier
                    || source.kind == .unevenRoundedRectangle
                encodedBatchKey = resolveShapeBatchKey(.init(
                    blendMode: source.blendMode,
                    usesGradient: source.gradientSlot != .max
                ))
                    | (isExtended ? 0xc000_0000 : 0x8000_0000)
                family = isExtended ? .extendedShape : .shape
                sourceLayer = source.layer
                sourceOrder = source.order
                sourceBoundsMinimum = source.boundsMinimum
                sourceBoundsMaximum = source.boundsMaximum
                spriteInstance = Self.emptySpriteInstance
                shapeInstance = ShapeInstance(
                    transformX: source.transformX,
                    transformY: source.transformY,
                    translation: source.transformTranslation,
                    quadHalfExtent: source.quadHalfExtent,
                    parameters: source.parameters,
                    fillColor: source.gradientSlot == .max ? source.fillColor : source.gradientLine,
                    strokeColor: source.strokeColor,
                    style: .init(
                        Float(source.kind.rawValue)
                            + (source.gradientSlot == .max ? 0 : Float(source.gradientSlot + 1) * 64)
                            + Float(source.gradientPlacement) * 16_384,
                        source.strokeWidth,
                        source.strokeAlignment + source.smoothAntialiasing * 4,
                        source.rounding
                    )
                )
                extendedShapeInstance = ExtendedShapeInstance(
                    transformX: source.transformX,
                    transformY: source.transformY,
                    translation: source.transformTranslation,
                    quadHalfExtent: source.quadHalfExtent,
                    parameters: source.parameters,
                    extendedParameters: source.extendedParameters,
                    fillColor: source.gradientSlot == .max ? source.fillColor : source.gradientLine,
                    strokeColor: source.strokeColor,
                    style: .init(
                        Float(source.kind.rawValue)
                            + (source.gradientSlot == .max ? 0 : Float(source.gradientSlot + 1) * 64)
                            + Float(source.gradientPlacement) * 16_384,
                        source.strokeWidth,
                        source.strokeAlignment + source.smoothAntialiasing * 4,
                        source.rounding
                    )
                )
                primitiveInstance = Self.emptyPrimitiveInstance
            case .primitive(let source):
                encodedBatchKey = 0x4000_0000 | source.kind.rawValue
                family = .primitive
                sourceLayer = source.layer
                sourceOrder = source.order
                sourceBoundsMinimum = source.boundsMinimum
                sourceBoundsMaximum = source.boundsMaximum
                spriteInstance = Self.emptySpriteInstance
                shapeInstance = Self.emptyShapeInstance
                extendedShapeInstance = Self.emptyExtendedShapeInstance
                primitiveInstance = PrimitiveInstance(
                    transformX: source.transformX,
                    transformY: source.transformY,
                    translation: source.transformTranslation,
                    origin: source.origin,
                    size: source.size,
                    width: source.width,
                    colorRGBA8: Self.rgba8(source.color)
                )
            }
            let layerSlot: UInt32
            if index < initializedExecutionCount,
                orderingRecords[index].layer == sourceLayer
            {
                layerSlot = orderingRecords[index].layerSlot
            } else {
                layerSlot = resolveLayer(sourceLayer)
            }
            let ordering = OrderingRecord(
                layer: sourceLayer, order: sourceOrder, layerSlot: layerSlot)
            if index < initializedExecutionCount {
                boundsMinimum[index] = sourceBoundsMinimum
                boundsMaximum[index] = sourceBoundsMaximum
                orderingRecords[index] = ordering
                encodedBatchKeys[index] = encodedBatchKey
                instances[index] = spriteInstance
                shapeInstances[index] = shapeInstance
                extendedShapeInstances[index] = extendedShapeInstance
                primitiveInstances[index] = primitiveInstance
                families[index] = family
            } else {
                boundsMinimum.advanced(by: index).initialize(to: sourceBoundsMinimum)
                boundsMaximum.advanced(by: index).initialize(to: sourceBoundsMaximum)
                orderingRecords.advanced(by: index).initialize(to: ordering)
                encodedBatchKeys.advanced(by: index).initialize(to: encodedBatchKey)
                instances.advanced(by: index).initialize(to: spriteInstance)
                shapeInstances.advanced(by: index).initialize(to: shapeInstance)
                extendedShapeInstances.advanced(by: index).initialize(to: extendedShapeInstance)
                primitiveInstances.advanced(by: index).initialize(to: primitiveInstance)
                families.advanced(by: index).initialize(to: family)
            }
        }
        initializedExecutionCount = max(initializedExecutionCount, count)
    }

    private func cull(views: UnsafeBufferPointer<View>) -> Int {
        var visibleCount = 0
        for index in 0..<count {
            let minimum = boundsMinimum[index]
            let maximum = boundsMaximum[index]
            var mask = UInt64(0)
            for viewIndex in views.indices {
                let view = views[viewIndex]
                if maximum.x >= view.boundsMinimum.x
                    && minimum.x <= view.boundsMaximum.x
                    && maximum.y >= view.boundsMinimum.y
                    && minimum.y <= view.boundsMaximum.y
                {
                    mask |= UInt64(1) << viewIndex
                }
            }
            visibilityMasks[index] = mask
            if mask != 0 {
                visibleUnion[visibleCount] = UInt32(index)
                visibleCount += 1
            }
        }
        return visibleCount
    }

    private func bin(visibleCount: Int) -> Int {
        layerGeneration &+= 1
        if layerGeneration == 0 {
            for index in 0..<layerCount { layerBins[index].generation = 0 }
            layerGeneration = 1
        }
        var activeCount = 0
        for position in 0..<visibleCount {
            let ordinal = visibleUnion[position]
            let ordering = orderingRecords[Int(ordinal)]
            let slot = Int(ordering.layerSlot)
            if layerBins[slot].generation == layerGeneration {
                layerBins[slot].count += 1
                layerBins[slot].varyingOrderBits |= layerBins[slot].firstOrder ^ ordering.order
            } else {
                layerBins[slot].firstOrder = ordering.order
                layerBins[slot].count = 1
                layerBins[slot].offset = 0
                layerBins[slot].cursor = 0
                layerBins[slot].varyingOrderBits = 0
                layerBins[slot].generation = layerGeneration
                activeLayerSlots[activeCount] = ordering.layerSlot
                activeCount += 1
            }
        }
        var active = UnsafeMutableBufferPointer(start: activeLayerSlots, count: activeCount)
        active.sort { layerBins[Int($0)].layer < layerBins[Int($1)].layer }
        var offset = 0
        for index in 0..<activeCount {
            let slot = Int(activeLayerSlots[index])
            layerBins[slot].offset = offset
            layerBins[slot].cursor = offset
            offset += layerBins[slot].count
        }
        for position in 0..<visibleCount {
            let ordinal = visibleUnion[position]
            let ordering = orderingRecords[Int(ordinal)]
            let slot = Int(ordering.layerSlot)
            let destination = layerBins[slot].cursor
            orderedKeys[destination] = (UInt64(ordering.order) << 32) | UInt64(ordinal)
            layerBins[slot].cursor += 1
        }
        return activeCount
    }

    private func order(visibleCount: Int, activeLayerCount: Int) {
        guard visibleCount > 1 else { return }
        for activeIndex in 0..<activeLayerCount {
            let layer = layerBins[Int(activeLayerSlots[activeIndex])]
            guard layer.count > 1 else { continue }
            var sourceIsOrdered = true
            for byte in 0..<4 {
                let shift = byte * 8
                guard layer.varyingOrderBits & (UInt32(0xff) << shift) != 0 else { continue }
                Self.radixPass(
                    source: sourceIsOrdered ? orderedKeys : orderingScratch,
                    destination: sourceIsOrdered ? orderingScratch : orderedKeys,
                    counts: radixCounts,
                    start: layer.offset,
                    count: layer.count,
                    shift: UInt64(32 + shift)
                )
                sourceIsOrdered.toggle()
            }
            if !sourceIsOrdered {
                for index in layer.offset..<(layer.offset + layer.count) {
                    orderedKeys[index] = orderingScratch[index]
                }
            }
        }
    }

    private func formBatches(visibleCount: Int, viewCount: Int) {
        for index in 0..<viewCount { viewContexts[index].state = .init() }
        for position in 0..<visibleCount {
            let ordinal = UInt32(truncatingIfNeeded: orderedKeys[position])
            let encodedKey = encodedBatchKeys[Int(ordinal)]
            var mask = visibilityMasks[Int(ordinal)]
            while mask != 0 {
                append(
                    ordinal: ordinal, encodedKey: encodedKey,
                    to: viewContexts.advanced(by: mask.trailingZeroBitCount))
                mask &= mask - 1
            }
        }
        for index in 0..<viewCount {
            let context = viewContexts.advanced(by: index)
            var state = context.pointee.state
            if state.hasPrevious {
                context.pointee.batches[Int(state.batchCount)] = Batch(
                    family: Self.family(for: state.previousKey),
                    key: state.previousKey & 0x3fff_ffff,
                    end: state.visibleCount)
                state.batchCount += 1
                context.pointee.state = state
            }
        }
    }

    @inline(__always)
    private func append(
        ordinal: UInt32, encodedKey: UInt32, to context: UnsafeMutablePointer<ViewContext>
    ) {
        var state = context.pointee.state
        if state.hasPrevious && encodedKey != state.previousKey {
            context.pointee.batches[Int(state.batchCount)] = Batch(
                family: Self.family(for: state.previousKey),
                key: state.previousKey & 0x3fff_ffff,
                end: state.visibleCount)
            state.batchCount += 1
        }
        context.pointee.ordinals[Int(state.visibleCount)] = ordinal
        state.visibleCount += 1
        state.previousKey = encodedKey
        state.hasPrevious = true
        context.pointee.state = state
    }

    private func resolveLayer(_ layer: UInt32) -> UInt32 {
        var index = Int(truncatingIfNeeded: Self.mix(UInt64(layer)))
            & (registryCapacity - 1)
        while layerRegistry[index].occupied {
            if layerRegistry[index].value == UInt64(layer) { return layerRegistry[index].slot }
            index = (index + 1) & (registryCapacity - 1)
        }
        precondition(
            layerCount < settings.capacity,
            "Render queue layer capacity exceeded: capacity \(settings.capacity), attempted count \(layerCount + 1)"
        )
        let slot = UInt32(layerCount)
        layerBins.advanced(by: layerCount).initialize(
            to: LayerBin(
                layer: layer, firstOrder: 0, count: 0, offset: 0, cursor: 0, varyingOrderBits: 0,
                generation: 0)
        )
        layerCount += 1
        layerRegistry[index] = RegistryEntry(value: UInt64(layer), slot: slot, occupied: true)
        return slot
    }

    private func resolveSpriteBatchKey(_ key: SpriteBatchKey) -> UInt32 {
        let hash = Self.spriteBatchKeyHash(key)
        var index = Int(truncatingIfNeeded: hash) & (registryCapacity - 1)
        while spriteBatchKeyRegistry[index].occupied {
            let slot = spriteBatchKeyRegistry[index].slot
            if spriteBatchKeys[Int(slot)] == key { return slot }
            index = (index + 1) & (registryCapacity - 1)
        }
        precondition(
            spriteBatchKeyCount < settings.capacity,
            "Render queue sprite-batch-key capacity exceeded: capacity \(settings.capacity), attempted count \(spriteBatchKeyCount + 1)"
        )
        let slot = UInt32(spriteBatchKeyCount)
        spriteBatchKeys.advanced(by: spriteBatchKeyCount).initialize(to: key)
        spriteBatchKeyCount += 1
        spriteBatchKeyRegistry[index] = RegistryEntry(value: hash, slot: slot, occupied: true)
        return slot
    }

    private func resolveShapeBatchKey(_ key: ShapeBatchKey) -> UInt32 {
        for index in 0..<shapeBatchKeyCount where shapeBatchKeys[index] == key {
            return UInt32(index)
        }
        precondition(
            shapeBatchKeyCount < settings.capacity,
            "Render queue shape-batch-key capacity exceeded: capacity \(settings.capacity), attempted count \(shapeBatchKeyCount + 1)"
        )
        let slot = UInt32(shapeBatchKeyCount)
        shapeBatchKeys.advanced(by: shapeBatchKeyCount).initialize(to: key)
        shapeBatchKeyCount += 1
        return slot
    }

    private static let emptySpriteInstance = Instance(
        transformX: .zero,
        transformY: .zero,
        translation: .zero,
        textureOrigin: .zero,
        textureScale: .zero,
        tintRGBA8: 0,
        modulationMode: 0
    )

    private static let emptyShapeInstance = ShapeInstance(
        transformX: .zero,
        transformY: .zero,
        translation: .zero,
        quadHalfExtent: .zero,
        parameters: .zero,
        fillColor: .zero,
        strokeColor: .zero,
        style: .zero
    )

    private static let emptyExtendedShapeInstance = ExtendedShapeInstance(
        transformX: .zero,
        transformY: .zero,
        translation: .zero,
        quadHalfExtent: .zero,
        parameters: .zero,
        extendedParameters: .zero,
        fillColor: .zero,
        strokeColor: .zero,
        style: .zero
    )

    private static let emptyPrimitiveInstance = PrimitiveInstance(
        transformX: .zero,
        transformY: .zero,
        translation: .zero,
        origin: .zero,
        size: .zero,
        width: 0,
        colorRGBA8: 0
    )

    private static func family(for encodedMaterial: UInt32) -> Family {
        switch encodedMaterial >> 30 {
        case 0: .sprite
        case 1: .primitive
        case 2: .shape
        default: .extendedShape
        }
    }

    private static func rgba8(_ color: SIMD4<Float>) -> UInt32 {
        func channel(_ value: Float) -> UInt32 {
            UInt32((min(max(value, 0), 1) * 255).rounded())
        }
        return channel(color.x)
            | channel(color.y) << 8
            | channel(color.z) << 16
            | channel(color.w) << 24
    }

    private static func spriteBatchKeyHash(_ key: SpriteBatchKey) -> UInt64 {
        var value = mix(key.texture.rawValue)
        value ^= mix(UInt64(samplerCode(key.sampler)) << 1)
        switch key.blendMode {
        case .replace:
            break
        case .normal:
            value ^= 0x9e37_79b9_7f4a_7c15
        case .premultiplied:
            value ^= 0xc2b2_ae3d_27d4_eb4f
        }
        return mix(value)
    }

    private static func samplerCode(_ value: SamplerDescriptor) -> UInt32 {
        func filter(_ value: SamplerFilter) -> UInt32 { value == .linear ? 1 : 0 }
        func address(_ value: SamplerAddressMode) -> UInt32 {
            switch value {
            case .clampToEdge: 0
            case .repeat: 1
            case .mirrorRepeat: 2
            }
        }
        return filter(value.minFilter)
            | filter(value.magFilter) << 1
            | filter(value.mipFilter) << 2
            | address(value.addressModeU) << 3
            | address(value.addressModeV) << 5
            | address(value.addressModeW) << 7
    }

    private static func registryCapacity(for capacity: Int) -> Int {
        var value = 1
        while value < capacity * 2 { value <<= 1 }
        return value
    }

    private static func mix(_ source: UInt64) -> UInt64 {
        var value = source &+ 0x9e37_79b9_7f4a_7c15
        value = (value ^ (value >> 30)) &* 0xbf58_476d_1ce4_e5b9
        value = (value ^ (value >> 27)) &* 0x94d0_49bb_1331_11eb
        return value ^ (value >> 31)
    }

    private static func radixPass(
        source: UnsafeMutablePointer<UInt64>,
        destination: UnsafeMutablePointer<UInt64>,
        counts: UnsafeMutablePointer<Int>,
        start: Int,
        count: Int,
        shift: UInt64
    ) {
        for index in 0..<256 { counts[index] = 0 }
        for index in start..<(start + count) {
            counts[Int((source[index] >> shift) & 0xff)] += 1
        }
        var offset = start
        for index in 0..<256 {
            let total = counts[index]
            counts[index] = offset
            offset += total
        }
        for index in start..<(start + count) {
            let value = source[index]
            let bucket = Int((value >> shift) & 0xff)
            destination[counts[bucket]] = value
            counts[bucket] += 1
        }
    }

    private static func seconds(since start: ContinuousClock.Instant) -> Double {
        let components = (ContinuousClock.now - start).components
        return Double(components.seconds) + Double(components.attoseconds) * 1e-18
    }
}

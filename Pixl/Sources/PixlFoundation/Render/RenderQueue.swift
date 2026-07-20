import PixlPlatform
import Swift

/// Fixed-capacity retained submission and CPU execution storage.
///
/// `execute(views:_:)` lends transient execution buffers only for the duration
/// of its closure. Direct Foundation users reset explicitly; Pixl's
/// `GameContext` convenience resets its default queue automatically.
public final class RenderQueue {
    /// Fixed capacities allocated by a render queue.
    public struct Settings: Hashable, Sendable {
        /// Maximum number of submissions retained between resets.
        public var capacity: Int
        /// Maximum number of views processed by one execution. Defaults to `1`.
        public var viewCapacity: Int

        /// Creates fixed queue capacities.
        /// - Parameters:
        ///   - capacity: Positive maximum submission count.
        ///   - viewCapacity: Maximum simultaneous views in `1...64`.
        public init(capacity: Int = 10_000, viewCapacity: Int = 1) {
            precondition(capacity > 0)
            precondition(UInt64(capacity) <= UInt64(UInt32.max))
            precondition(capacity <= Int.max / 2)
            precondition((1...64).contains(viewCapacity))
            self.capacity = capacity
            self.viewCapacity = viewCapacity
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
            boundsMinimum: SIMD2<Float>,
            boundsMaximum: SIMD2<Float>
        ) {
            self.projectionX = projectionX
            self.projectionY = projectionY
            self.projectionTranslation = projectionTranslation
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
    }

    /// Resolved sprite draw compatibility shared by consecutive instances.
    public struct Material: Hashable, Sendable {
        /// Logical texture identity.
        public let texture: TextureResourceID
        /// Complete sampling state.
        public let sampler: SamplerDescriptor
        /// Fixed-function colour composition.
        public let blendMode: BlendMode
    }

    /// One consecutive range sharing a material slot.
    public struct Batch: BitwiseCopyable, Sendable {
        /// Index into ``Execution/materials``.
        public let material: UInt32
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
        /// Ordered indices into ``Execution/instances``.
        public let ordinals: UnsafeBufferPointer<UInt32>
        /// Consecutive compatible ranges over ``ordinals``.
        public let batches: UnsafeBufferPointer<Batch>
    }

    /// Transient read-only execution streams lent to an execution closure.
    public struct Execution {
        /// Ordinal-aligned lowered instance records.
        public let instances: UnsafeBufferPointer<Instance>
        /// Unique materials referenced by view batches.
        public let materials: UnsafeBufferPointer<Material>
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
        var previousMaterial = UInt32(0)
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

    private let submissions: UnsafeMutablePointer<SpriteSubmission>
    private let boundsMinimum: UnsafeMutablePointer<SIMD2<Float>>
    private let boundsMaximum: UnsafeMutablePointer<SIMD2<Float>>
    private let orderingRecords: UnsafeMutablePointer<OrderingRecord>
    private let materialSlots: UnsafeMutablePointer<UInt32>
    private let instances: UnsafeMutablePointer<Instance>
    private let visibilityMasks: UnsafeMutablePointer<UInt64>
    private let visibleUnion: UnsafeMutablePointer<UInt32>
    private let orderedKeys: UnsafeMutablePointer<UInt64>
    private let orderingScratch: UnsafeMutablePointer<UInt64>
    private let layerBins: UnsafeMutablePointer<LayerBin>
    private let activeLayerSlots: UnsafeMutablePointer<UInt32>
    private let layerRegistry: UnsafeMutablePointer<RegistryEntry>
    private let materialRegistry: UnsafeMutablePointer<RegistryEntry>
    private let materials: UnsafeMutablePointer<Material>
    private let radixCounts: UnsafeMutablePointer<Int>
    private let viewContexts: UnsafeMutablePointer<ViewContext>
    private let viewOutputs: UnsafeMutablePointer<ViewOutput>
    private let registryCapacity: Int
    private var initializedExecutionCount = 0
    private var layerCount = 0
    private var materialCount = 0
    private var layerGeneration = UInt32(0)

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
        materialSlots = .allocate(capacity: capacity)
        instances = .allocate(capacity: capacity)
        visibilityMasks = .allocate(capacity: capacity)
        visibleUnion = .allocate(capacity: capacity)
        orderedKeys = .allocate(capacity: capacity)
        orderingScratch = .allocate(capacity: capacity)
        layerBins = .allocate(capacity: capacity)
        activeLayerSlots = .allocate(capacity: capacity)
        layerRegistry = .allocate(capacity: registryCapacity)
        materialRegistry = .allocate(capacity: registryCapacity)
        materials = .allocate(capacity: capacity)
        radixCounts = .allocate(capacity: 256)
        viewContexts = .allocate(capacity: settings.viewCapacity)
        viewOutputs = .allocate(capacity: settings.viewCapacity)

        visibilityMasks.initialize(repeating: 0, count: capacity)
        visibleUnion.initialize(repeating: 0, count: capacity)
        orderedKeys.initialize(repeating: 0, count: capacity)
        orderingScratch.initialize(repeating: 0, count: capacity)
        activeLayerSlots.initialize(repeating: 0, count: capacity)
        layerRegistry.initialize(repeating: .empty, count: registryCapacity)
        materialRegistry.initialize(repeating: .empty, count: registryCapacity)
        radixCounts.initialize(repeating: 0, count: 256)

        for index in 0..<settings.viewCapacity {
            let ordinals = UnsafeMutablePointer<UInt32>.allocate(capacity: capacity)
            let batches = UnsafeMutablePointer<Batch>.allocate(capacity: capacity)
            ordinals.initialize(repeating: 0, count: capacity)
            batches.initialize(repeating: Batch(material: 0, end: 0), count: capacity)
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
        materialSlots.deinitialize(count: initializedExecutionCount)
        materialSlots.deallocate()
        instances.deinitialize(count: initializedExecutionCount)
        instances.deallocate()
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
        materialRegistry.deinitialize(count: registryCapacity)
        materialRegistry.deallocate()
        materials.deinitialize(count: materialCount)
        materials.deallocate()
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
    }

    /// Removes every retained submission while preserving allocated storage and caches.
    public func reset() {
        submissions.deinitialize(count: count)
        count = 0
    }

    /// Appends one sprite submission and assigns its global submission ordinal.
    /// - Parameter submission: Camera-independent sprite snapshot to retain until reset.
    public func submit(_ submission: SpriteSubmission) {
        precondition(count < settings.capacity, "Render queue capacity exceeded")
        submissions.advanced(by: count).initialize(to: submission)
        count += 1
    }

    package func addInstanceSeconds(_ seconds: Double) {
        latestMetrics.instancesSeconds += seconds
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
        precondition(!views.isEmpty && views.count <= settings.viewCapacity)
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
                instances: UnsafeBufferPointer(start: instances, count: count),
                materials: UnsafeBufferPointer(start: materials, count: materialCount),
                views: UnsafeBufferPointer(start: viewOutputs, count: views.count),
                metrics: metrics
            )
        )
    }

    private func lower() {
        for index in 0..<count {
            let source = submissions[index]
            let material = Material(
                texture: source.texture,
                sampler: source.sampler,
                blendMode: source.blendMode
            )
            let layerSlot: UInt32
            let materialSlot: UInt32
            if index < initializedExecutionCount,
                orderingRecords[index].layer == source.layer
            {
                layerSlot = orderingRecords[index].layerSlot
            } else {
                layerSlot = resolveLayer(source.layer)
            }
            if index < initializedExecutionCount,
                materials[Int(materialSlots[index])] == material
            {
                materialSlot = materialSlots[index]
            } else {
                materialSlot = resolveMaterial(material)
            }
            let ordering = OrderingRecord(
                layer: source.layer, order: source.order, layerSlot: layerSlot)
            let instance = Instance(
                transformX: source.transformX,
                transformY: source.transformY,
                translation: source.transformTranslation,
                textureOrigin: source.textureCoordinateOrigin,
                textureScale: source.textureCoordinateScale,
                tintRGBA8: source.tintRGBA8
            )
            if index < initializedExecutionCount {
                boundsMinimum[index] = source.boundsMinimum
                boundsMaximum[index] = source.boundsMaximum
                orderingRecords[index] = ordering
                materialSlots[index] = materialSlot
                instances[index] = instance
            } else {
                boundsMinimum.advanced(by: index).initialize(to: source.boundsMinimum)
                boundsMaximum.advanced(by: index).initialize(to: source.boundsMaximum)
                orderingRecords.advanced(by: index).initialize(to: ordering)
                materialSlots.advanced(by: index).initialize(to: materialSlot)
                instances.advanced(by: index).initialize(to: instance)
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
            let material = materialSlots[Int(ordinal)]
            var mask = visibilityMasks[Int(ordinal)]
            while mask != 0 {
                append(
                    ordinal: ordinal, material: material,
                    to: viewContexts.advanced(by: mask.trailingZeroBitCount))
                mask &= mask - 1
            }
        }
        for index in 0..<viewCount {
            let context = viewContexts.advanced(by: index)
            var state = context.pointee.state
            if state.hasPrevious {
                context.pointee.batches[Int(state.batchCount)] = Batch(
                    material: state.previousMaterial, end: state.visibleCount)
                state.batchCount += 1
                context.pointee.state = state
            }
        }
    }

    @inline(__always)
    private func append(
        ordinal: UInt32, material: UInt32, to context: UnsafeMutablePointer<ViewContext>
    ) {
        var state = context.pointee.state
        if state.hasPrevious && material != state.previousMaterial {
            context.pointee.batches[Int(state.batchCount)] = Batch(
                material: state.previousMaterial, end: state.visibleCount)
            state.batchCount += 1
        }
        context.pointee.ordinals[Int(state.visibleCount)] = ordinal
        state.visibleCount += 1
        state.previousMaterial = material
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
        precondition(layerCount < settings.capacity)
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

    private func resolveMaterial(_ material: Material) -> UInt32 {
        let hash = Self.materialHash(material)
        var index = Int(truncatingIfNeeded: hash) & (registryCapacity - 1)
        while materialRegistry[index].occupied {
            let slot = materialRegistry[index].slot
            if materials[Int(slot)] == material { return slot }
            index = (index + 1) & (registryCapacity - 1)
        }
        precondition(materialCount < settings.capacity)
        let slot = UInt32(materialCount)
        materials.advanced(by: materialCount).initialize(to: material)
        materialCount += 1
        materialRegistry[index] = RegistryEntry(value: hash, slot: slot, occupied: true)
        return slot
    }

    private static func materialHash(_ material: Material) -> UInt64 {
        var value = mix(material.texture.rawValue)
        value ^= mix(UInt64(samplerCode(material.sampler)) << 1)
        switch material.blendMode {
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

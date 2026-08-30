struct ColliderRecord2D {
    var bounds: Rect
    var broadBounds: Rect
    var proxy: ProxyID
    var nextFree: Int32
    var generation: UInt32
    var dynamicSlot: Int32
    var layerBit: UInt64
    var mask: CollisionMask
    var isDynamic: Bool
    var isLive: Bool

    static func live(
        bounds: Rect,
        broadBounds: Rect,
        generation: UInt32,
        layerBit: UInt64,
        mask: CollisionMask,
        isDynamic: Bool
    ) -> Self {
        Self(
            bounds: bounds,
            broadBounds: broadBounds,
            proxy: .init(index: -1, generation: 0),
            nextFree: -1,
            generation: generation,
            dynamicSlot: -1,
            layerBit: layerBit,
            mask: mask,
            isDynamic: isDynamic,
            isLive: true
        )
    }

    static func free(next: Int32, generation: UInt32) -> Self {
        Self(
            bounds: .zero,
            broadBounds: .zero,
            proxy: .init(index: -1, generation: 0),
            nextFree: next,
            generation: generation,
            dynamicSlot: -1,
            layerBit: 0,
            mask: .none,
            isDynamic: false,
            isLive: false
        )
    }
}

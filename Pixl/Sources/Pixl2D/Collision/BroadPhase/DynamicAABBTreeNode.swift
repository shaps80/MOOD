import Swift

struct DynamicAABBTreeNode {
    static let nullIndex: Int32 = -1

    var bounds: SIMD4<Float>
    var parent: Int32
    var childA: Int32
    var childB: Int32
    var height: Int32
    var nextFree: Int32
    var generation: UInt32
    var userData: Int32

    var isLeaf: Bool { childA == Self.nullIndex }

    var rect: Rect {
        Rect(
            x: bounds.x,
            y: bounds.y,
            width: bounds.z - bounds.x,
            height: bounds.w - bounds.y
        )
    }

    static func allocated(generation: UInt32) -> Self {
        Self(
            bounds: .zero,
            parent: nullIndex,
            childA: nullIndex,
            childB: nullIndex,
            height: 0,
            nextFree: nullIndex,
            generation: generation,
            userData: nullIndex
        )
    }

    static func leaf(
        bounds: Rect,
        generation: UInt32,
        userData: Int32
    ) -> Self {
        Self(
            bounds: .init(bounds.minX, bounds.minY, bounds.maxX, bounds.maxY),
            parent: nullIndex,
            childA: nullIndex,
            childB: nullIndex,
            height: 0,
            nextFree: nullIndex,
            generation: generation,
            userData: userData
        )
    }

    static func branch(
        bounds: SIMD4<Float>,
        parent: Int32,
        childA: Int32,
        childB: Int32,
        height: Int32,
        generation: UInt32
    ) -> Self {
        Self(
            bounds: bounds,
            parent: parent,
            childA: childA,
            childB: childB,
            height: height,
            nextFree: nullIndex,
            generation: generation,
            userData: nullIndex
        )
    }

    static func free(next: Int32, generation: UInt32) -> Self {
        Self(
            bounds: .zero,
            parent: nullIndex,
            childA: nullIndex,
            childB: nullIndex,
            height: -1,
            nextFree: next,
            generation: generation,
            userData: nullIndex
        )
    }
}

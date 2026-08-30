/// Stable identity for one live proxy in a `DynamicAABBTree2D`.
package struct ProxyID: Equatable, Sendable {
    let index: Int32
    let generation: UInt32

    init(index: Int32, generation: UInt32) {
        self.index = index
        self.generation = generation
    }
}

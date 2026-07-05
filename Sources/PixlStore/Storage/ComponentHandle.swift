public struct ComponentHandle<Schema: ComponentSchema, Group: StorageGroup>: Hashable, Sendable {
    public let index: Int
    public let generation: Int

    public init(index: Int, generation: Int) {
        self.index = index
        self.generation = generation
    }
}


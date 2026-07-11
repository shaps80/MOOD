public protocol _PixlComponentType: FrameComponent {
    associatedtype _PixlSchema: ComponentSchema
    associatedtype _PixlGroup: StorageGroup

    var _pixlComponentHandle: ComponentHandle<_PixlSchema, _PixlGroup> { get }

    init(
        handle: ComponentHandle<_PixlSchema, _PixlGroup>,
        row: Int,
        frameID: UInt64,
        storage: Store
    )
}

public struct EntityPropertyColumn<Value> {
    public var values: [Value]
    public var handleIndices: [Int]
    public var handleGenerations: [Int]
    public var componentStore: AnyObject?

    public init() {
        self.values = []
        self.handleIndices = []
        self.handleGenerations = []
        self.componentStore = nil
    }
}

public func _pixlInitializeEntityColumn<Value>(
    _ column: inout EntityPropertyColumn<Value>,
    capacity: Int,
    defaultValue: Value?
) {
    guard let defaultValue else {
        preconditionFailure("PixlStore: entity value property requires a default value.")
    }

    column.values = Array(repeating: defaultValue, count: capacity)
    column.handleIndices = []
    column.handleGenerations = []
    column.componentStore = nil
}

public func _pixlInitializeEntityColumn<Value: _PixlComponentType>(
    _ column: inout EntityPropertyColumn<Value>,
    capacity: Int,
    defaultValue: Value?
) {
    column.values = []
    column.handleIndices = Array(repeating: -1, count: capacity)
    column.handleGenerations = Array(repeating: -1, count: capacity)
    column.componentStore = nil
}

public func _pixlGrowEntityColumn<Value>(
    _ column: inout EntityPropertyColumn<Value>,
    from oldCapacity: Int,
    to newCapacity: Int,
    defaultValue: Value?
) {
    guard let defaultValue else {
        preconditionFailure("PixlStore: entity value property requires a default value.")
    }

    column.values.append(contentsOf: repeatElement(defaultValue, count: newCapacity - oldCapacity))
}

public func _pixlGrowEntityColumn<Value: _PixlComponentType>(
    _ column: inout EntityPropertyColumn<Value>,
    from oldCapacity: Int,
    to newCapacity: Int,
    defaultValue: Value?
) {
    column.handleIndices.append(contentsOf: repeatElement(-1, count: newCapacity - oldCapacity))
    column.handleGenerations.append(contentsOf: repeatElement(-1, count: newCapacity - oldCapacity))
}

public func _pixlResetEntityColumnRow<Value>(
    _ column: inout EntityPropertyColumn<Value>,
    row: Int,
    defaultValue: Value?
) {
    guard let defaultValue else {
        preconditionFailure("PixlStore: entity value property requires a default value.")
    }

    column.values[row] = defaultValue
}

public func _pixlResetEntityColumnRow<Value: _PixlComponentType>(
    _ column: inout EntityPropertyColumn<Value>,
    row: Int,
    defaultValue: Value?
) {
    column.handleIndices[row] = -1
    column.handleGenerations[row] = -1
}

public func _pixlSwapEntityColumnRows<Value>(
    _ column: inout EntityPropertyColumn<Value>,
    _ lhs: Int,
    _ rhs: Int
) {
    if !column.values.isEmpty {
        column.values.swapAt(lhs, rhs)
    }

    if !column.handleIndices.isEmpty {
        column.handleIndices.swapAt(lhs, rhs)
        column.handleGenerations.swapAt(lhs, rhs)
    }
}

public func _pixlMoveEntityColumnRow<Value>(
    _ column: inout EntityPropertyColumn<Value>,
    from source: Int,
    to destination: Int
) {
    if !column.values.isEmpty {
        column.values[destination] = column.values[source]
    }

    if !column.handleIndices.isEmpty {
        column.handleIndices[destination] = column.handleIndices[source]
        column.handleGenerations[destination] = column.handleGenerations[source]
    }
}

public func _pixlReadEntityProperty<Value>(
    storage: Store,
    column: EntityPropertyColumn<Value>,
    row: Int,
    as type: Value.Type
) -> Value {
    column.values[row]
}

public func _pixlWriteEntityProperty<Value>(
    storage: Store,
    column: inout EntityPropertyColumn<Value>,
    row: Int,
    value: Value
) {
    column.values[row] = value
}

public func _pixlReadEntityProperty<Value: _PixlComponentType>(
    storage: Store,
    column: EntityPropertyColumn<Value>,
    row: Int,
    as type: Value.Type
) -> Value {
    let handle = ComponentHandle<Value._PixlSchema, Value._PixlGroup>(
        index: column.handleIndices[row],
        generation: column.handleGenerations[row]
    )
    let componentStore = column.componentStore as? ComponentStore<Value._PixlSchema, Value._PixlGroup>
        ?? storage._pixlStore(Value._PixlSchema.self, Value._PixlGroup.self)
    let componentRow = componentStore.row(for: handle)!
    return Value(handle: handle, row: componentRow, frameID: storage.currentFrameID, storage: storage)
}

public func _pixlWriteEntityProperty<Value: _PixlComponentType>(
    storage: Store,
    column: inout EntityPropertyColumn<Value>,
    row: Int,
    value: Value
) {
    column.handleIndices[row] = value._pixlComponentHandle.index
    column.handleGenerations[row] = value._pixlComponentHandle.generation
}

public func _pixlCreateEntityProperty<Value>(
    storage: Store,
    column: inout EntityPropertyColumn<Value>,
    row: Int,
    as type: Value.Type
) {}

public func _pixlDestroyEntityProperty<Value>(
    storage: Store,
    column: inout EntityPropertyColumn<Value>,
    row: Int,
    as type: Value.Type
) {}

public func _pixlCreateEntityProperty<Value: _PixlComponentType>(
    storage: Store,
    column: inout EntityPropertyColumn<Value>,
    row: Int,
    as type: Value.Type
) {
    let componentStore = storage._pixlStore(Value._PixlSchema.self, Value._PixlGroup.self)
    column.componentStore = componentStore
    let handle = componentStore.appendSlot().handle
    column.handleIndices[row] = handle.index
    column.handleGenerations[row] = handle.generation
}

public func _pixlDestroyEntityProperty<Value: _PixlComponentType>(
    storage: Store,
    column: inout EntityPropertyColumn<Value>,
    row: Int,
    as type: Value.Type
) {
    let handle = ComponentHandle<Value._PixlSchema, Value._PixlGroup>(
        index: column.handleIndices[row],
        generation: column.handleGenerations[row]
    )
    let componentStore = column.componentStore as? ComponentStore<Value._PixlSchema, Value._PixlGroup>
        ?? storage._pixlStore(Value._PixlSchema.self, Value._PixlGroup.self)
    componentStore.remove(handle)
    column.handleIndices[row] = -1
    column.handleGenerations[row] = -1
}

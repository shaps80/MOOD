public protocol ComponentSchema {
    associatedtype Columns: ComponentColumns

    static var name: StaticString { get }
}

public protocol ComponentColumns {
    init()

    mutating func initializeStorage(capacity: Int)
    mutating func growStorage(from oldCapacity: Int, to newCapacity: Int)
    mutating func resetRowToDefault(_ row: Int)
    mutating func swapRows(_ lhs: Int, _ rhs: Int)
    mutating func moveRow(from source: Int, to destination: Int)
}



public protocol EntityColumns: ComponentColumns {
    var entityID: [EntityID] { get set }
}

public protocol EntitySchema: ComponentSchema where Columns: EntityColumns {}

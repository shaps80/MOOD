public protocol StorageGroup {
    static var name: StaticString { get }
    static var orderPolicy: OrderPolicy { get }
    static var initialCapacity: Int { get }
    static var emitsGrowthWarnings: Bool { get }
}

public extension StorageGroup {
    static var initialCapacity: Int { 256 }
    static var emitsGrowthWarnings: Bool { true }
}


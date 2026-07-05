public protocol ComponentCapability {
    associatedtype Schema: ComponentSchema
    associatedtype StorageGroupType: StorageGroup
}

public protocol PixlStoreSchemaType {
    static var pixlSchemaMetadata: [PixlPropertyMetadata] { get }
}

public struct PixlPropertyMetadata {
    public enum StorageKind: Equatable {
        case value
        case component
    }

    public let name: String
    public let valueType: Any.Type
    public let hasDefaultValue: Bool

    public init(
        name: String,
        valueType: Any.Type,
        hasDefaultValue: Bool
    ) {
        self.name = name
        self.valueType = valueType
        self.hasDefaultValue = hasDefaultValue
    }
}

public struct PixlResolvedProperty {
    public let name: String
    public let valueType: Any.Type
    public let storageKind: PixlPropertyMetadata.StorageKind
    public let hasDefaultValue: Bool
}

public struct PixlResolvedType {
    public let type: Any.Type
    public let properties: [PixlResolvedProperty]
}

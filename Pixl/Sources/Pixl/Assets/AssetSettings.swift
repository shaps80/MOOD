import Swift

public struct AssetSettings: Hashable, Sendable {
    public let path: String

    public init(path: String = "Assets") {
        precondition(!path.isEmpty, "Asset path must not be empty")
        self.path = path
    }

    public static let `default`: Self = .init()
}

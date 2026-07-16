import Swift

public struct AssetSettings: Hashable, Sendable {
    public let path: String
    let sourcePath: String

    public init(
        path: String = "Assets",
        relativeTo sourceFile: StaticString = #filePath
    ) {
        precondition(!path.isEmpty, "Asset path must not be empty")
        self.path = path
        sourcePath = String(describing: sourceFile)
    }
}

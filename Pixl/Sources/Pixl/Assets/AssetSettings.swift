import Swift

/// Location of a game's packaged asset directory.
public struct AssetSettings: Hashable, Sendable {
    /// Directory name or relative path packaged with the game.
    public let path: String
    let sourcePath: String

    /// Creates asset packaging settings relative to the declaring source file.
    /// - Parameters:
    ///   - path: Nonempty asset directory name or relative path.
    ///   - sourceFile: Calling source file used to resolve development assets.
    public init(
        path: String = "Assets",
        relativeTo sourceFile: StaticString = #filePath
    ) {
        precondition(!path.isEmpty, "Asset path must not be empty")
        self.path = path
        sourcePath = String(describing: sourceFile)
    }
}

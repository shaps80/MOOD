import Swift

/// Source location captured by a memory declaration or operation.
public struct SourceLocation: Hashable, Sendable {
    public let fileID: String
    public let line: UInt

    public init(fileID: StaticString = #fileID, line: UInt = #line) {
        self.fileID = String(describing: fileID)
        self.line = line
    }

    var description: String {
        "\(fileID):\(line)"
    }
}

import Swift

/// Source location captured by a memory declaration or operation.
internal struct SourceLocation: Hashable, Sendable {
    let fileID: String
    let line: UInt

    public init(fileID: StaticString = #fileID, line: UInt = #line) {
        self.fileID = String(describing: fileID)
        self.line = line
    }

    var description: String {
        "\(fileID):\(line)"
    }
}

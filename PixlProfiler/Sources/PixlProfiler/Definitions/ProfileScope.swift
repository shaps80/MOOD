/// Declare as static constants and include every definition in the session schema.
public struct ProfileScope: Sendable {
    public enum Kind: Sendable { case work, wait, frame, gpuFrame }
    public let id: UInt32
    public let name: StaticString
    public let kind: Kind
    public let parentScope: UInt32?
    public init(_ id: UInt32, _ name: StaticString, kind: Kind = .work, parentScope: UInt32? = nil) {
        self.id = id; self.name = name; self.kind = kind; self.parentScope = parentScope
    }
}

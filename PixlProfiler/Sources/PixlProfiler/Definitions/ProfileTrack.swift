/// A static track definition. Instances give a fixed worker pool separate lanes
/// without constructing names on workers. Never register tracks during capture.
public struct ProfileTrack: Sendable {
    public let id: UInt32
    public let name: StaticString
    public init(_ id: UInt32, _ name: StaticString) { self.id = id; self.name = name }
}

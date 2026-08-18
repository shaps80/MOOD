import Swift

public struct BillboardRenderer: Codable, Equatable, Sendable {
    public enum SizeSpace: String, CaseIterable, Codable, Hashable, Sendable {
        case world
        case screen
    }

    public enum Facing: String, CaseIterable, Codable, Hashable, Sendable {
        case camera
        case cameraPlane
        case cameraPosition
    }

    public var sizeSpace: SizeSpace
    public var facing: Facing

    public init(
        sizeSpace: SizeSpace = .world,
        facing: Facing = .camera
    ) {
        self.sizeSpace = sizeSpace
        self.facing = facing
    }
}

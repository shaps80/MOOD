import Swift

public struct ParticleRenderer: Codable, Equatable, Sendable {
    public enum Mode: String, CaseIterable, Codable, Hashable, Sendable {
        case point
        case billboard
    }

    public var mode: Mode
    public var billboard: BillboardRenderer

    public init(
        mode: Mode = .point,
        billboard: BillboardRenderer = .init()
    ) {
        self.mode = mode
        self.billboard = billboard
    }
}

import Pixl2D

/// Nearby surface normals sampled for one platformer simulation step.
///
/// Normals point out of the detected surface toward the character. A zero
/// vector means that the corresponding probe found no surface.
public struct PlatformerSurfaces: Equatable, Sendable {
    public var groundNormal: Vec2
    public var ceilingNormal: Vec2
    public var wallNormal: Vec2

    public init(
        groundNormal: Vec2 = .zero,
        ceilingNormal: Vec2 = .zero,
        wallNormal: Vec2 = .zero
    ) {
        self.groundNormal = groundNormal
        self.ceilingNormal = ceilingNormal
        self.wallNormal = wallNormal
    }
}

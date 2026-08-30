import Pixl
import Pixl2D

extension RenderLayer {
    static let environment: Self = 100
    static let entity: Self = 200
    static let gizmo: Self = 1_000
    static let shape: Self = 300
}

extension CollisionLayer {
    static let world: Self = 0
    static let character: Self = 1
}

extension CollisionMask {
    static let world: Self = .init(.world)
    static let character: Self = .init(.character)
}

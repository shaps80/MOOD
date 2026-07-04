import Pixl

extension Collider.Layer {
    static let world: Self = 0
    static let player: Self = 1
    static let bullet: Self = 2
    static let invader: Self = 3
}

extension Collider.Layer.Mask {
    static let world = Self(Collider.Layer.world)
    static let player = Self(Collider.Layer.player)
    static let bullet = Self(Collider.Layer.bullet)
    static let invader = Self(Collider.Layer.invader)

    static let playerMovement: Self = [.world]
    static let playerContact: Self = [.world, .invader]
    static let bulletContact: Self = [.world, .invader]
    static let invaderContact: Self = [.bullet, .player]
}

extension RenderLayer {
    static let world: Self = 100
    static let entity: Self = 200
}


import Pixl

extension Collider.Layer {
    public static let world: Self = 0
    public static let player: Self = 1
    public static let pickup: Self = 2
    public static let enemy: Self = 3
}

extension Collider.Layer.Mask {
    public static let world = Self(Collider.Layer.world)
    public static let player = Self(Collider.Layer.player)
    public static let pickup = Self(Collider.Layer.pickup)
    public static let enemy = Self(Collider.Layer.enemy)

    static let playerMovement: Self = [.world]
    static let playerInteractions: Self = [.pickup]
    static let enemyMovement: Self = [.world, .player]
}

extension RenderLayer {
    static let background: Self = 0
    static let world: Self = 100
    static let entity: Self = 200
    static let foreground: Self = 300
    static let debug: Self = 900
    static let overlay: Self = 1000
}

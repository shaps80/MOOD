import PixlStore

@Component
public struct Transform {
    public var position: Vec2 = .zero
    public var rotation: Double = 0
}

@Entity
public struct Player {
    public var transform: Transform
    public var health: Int = 3
}

@Entity
public struct Enemy {
    public var transform: Transform
    public var health: Int = 1
}

@Entity
public struct Bullet {
    public var transform: Transform
    public var velocity: Vec2 = .zero
    public var damage: Int = 1
}

public func storageProofExample() {
    let world = Store()
    world.beginFrame()

    let player = world.spawn(Player.self)
    player.health = 8
    player.transform.position = Vec2(x: 10, y: 20)

    let enemy = world.spawn(Enemy.self)
    enemy.health -= 1
    enemy.transform.position = Vec2(x: 24, y: 20)

    let bullet = world.spawn(Bullet.self)
    bullet.transform.position = player.transform.position
    bullet.velocity = Vec2(x: 0, y: -12)
    bullet.damage = 2

    for bullet in world.entities.ofType(Bullet.self) {
        bullet.transform.position += bullet.velocity
    }
}

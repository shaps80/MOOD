import XCTest
import PixlStore

final class PixlStoreBehaviorTests: XCTestCase {
    func testStoreRegistrationResolvesEntityComponentProperties() {
        let world = Store(for: [
            Transform.self,
            Player.self,
            Enemy.self,
            Bullet.self
        ])

        let player = world.resolvedType(for: Player.self)
        XCTAssertEqual(player?.properties.count, 2)
        XCTAssertEqual(player?.properties[0].name, "transform")
        XCTAssertEqual(player?.properties[0].storageKind, .component)
        XCTAssertEqual(player?.properties[1].name, "health")
        XCTAssertEqual(player?.properties[1].storageKind, .value)
        XCTAssertTrue(player?.properties[1].hasDefaultValue == true)

        let transform = world.resolvedType(for: Transform.self)
        XCTAssertEqual(transform?.properties.map(\.storageKind), [.value, .value])
    }

    func testSpawnReturnsLiveEntityAndMutationsWriteToColumns() {
        let world = Store()
        world.beginFrame()

        let bullet = world.spawn(Bullet.self)
        bullet.damage = 7
        bullet.velocity = Vec2(x: 3, y: -2)
        bullet.transform.position = Vec2(x: 10, y: 20)

        XCTAssertEqual(world._pixlStore(BulletSchema.self, BulletGroup.self).metrics.activeCount, 1)
        XCTAssertEqual(world._pixlStore(TransformSchema.self, TransformGroup.self).metrics.activeCount, 1)
        XCTAssertEqual(world._pixlStore(BulletSchema.self, BulletGroup.self).columns.damage.values[0], 7)
        XCTAssertEqual(world._pixlStore(BulletSchema.self, BulletGroup.self).columns.velocity.values[0], Vec2(x: 3, y: -2))
        XCTAssertEqual(world._pixlStore(TransformSchema.self, TransformGroup.self).columns.position[0], Vec2(x: 10, y: 20))
    }

    func testEntityLevelComponentSplitsIntoSeparateComponentStorage() {
        let world = Store()
        world.beginFrame()

        let player = world.spawn(Player.self)
        let enemy = world.spawn(Enemy.self)
        let bullet = world.spawn(Bullet.self)

        player.transform.position = Vec2(x: 1, y: 2)
        enemy.transform.position = Vec2(x: 3, y: 4)
        bullet.transform.position = Vec2(x: 5, y: 6)

        XCTAssertEqual(world._pixlStore(PlayerSchema.self, PlayerGroup.self).metrics.activeCount, 1)
        XCTAssertEqual(world._pixlStore(EnemySchema.self, EnemyGroup.self).metrics.activeCount, 1)
        XCTAssertEqual(world._pixlStore(BulletSchema.self, BulletGroup.self).metrics.activeCount, 1)
        XCTAssertEqual(world._pixlStore(TransformSchema.self, TransformGroup.self).metrics.activeCount, 3)
        XCTAssertEqual(world._pixlStore(TransformSchema.self, TransformGroup.self).columns.position[0], Vec2(x: 1, y: 2))
        XCTAssertEqual(world._pixlStore(TransformSchema.self, TransformGroup.self).columns.position[1], Vec2(x: 3, y: 4))
        XCTAssertEqual(world._pixlStore(TransformSchema.self, TransformGroup.self).columns.position[2], Vec2(x: 5, y: 6))
    }

    func testSimpleEntityPropertiesStayInEntityStorage() {
        let world = Store()
        world.beginFrame()

        let player = world.spawn(Player.self)
        let enemy = world.spawn(Enemy.self)

        player.health = 9
        enemy.health = 2

        XCTAssertEqual(world._pixlStore(PlayerSchema.self, PlayerGroup.self).columns.health.values[0], 9)
        XCTAssertEqual(world._pixlStore(EnemySchema.self, EnemyGroup.self).columns.health.values[0], 2)
        XCTAssertTrue(world._pixlStore(TransformSchema.self, TransformGroup.self).columns.position.allSatisfy { $0 == .zero })
    }

    func testQueryAndLookupReturnLiveViews() {
        let world = Store()
        world.beginFrame()

        let first = world.spawn(Bullet.self)
        let second = world.spawn(Bullet.self)
        first.damage = 1
        second.damage = 2

        let ids = Array(world.entities.ofType(Bullet.self).map(\.id))
        XCTAssertEqual(ids, [first.id, second.id])

        world.entity(id: second.id, as: Bullet.self)?.damage += 10
        XCTAssertEqual(
            Array(world._pixlStore(BulletSchema.self, BulletGroup.self).columns.damage.values.prefix(2)),
            [1, 12]
        )
    }

    func testDespawnRemovesEntityAndItsSplitComponent() {
        let world = Store()
        world.beginFrame()

        let bullet = world.spawn(Bullet.self)
        bullet.transform.position = Vec2(x: 4, y: 8)

        world.despawn(bullet.id)

        XCTAssertNil(world.entity(id: bullet.id, as: Bullet.self))
        XCTAssertEqual(world._pixlStore(BulletSchema.self, BulletGroup.self).metrics.activeCount, 0)
        XCTAssertEqual(world._pixlStore(TransformSchema.self, TransformGroup.self).metrics.activeCount, 0)
    }

}

import XCTest
import PixlStore

final class PixlStorePerformanceTests: XCTestCase {
    private let enemyCount = 25_000
    private let bulletCount = 100_000

    func testMeasureLargeWorldSpawn() {
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            let world = Store()
            world.beginFrame()

            _ = world.spawn(Player.self)

            for _ in 0..<enemyCount {
                _ = world.spawn(Enemy.self)
            }

            for _ in 0..<bulletCount {
                _ = world.spawn(Bullet.self)
            }

            XCTAssertEqual(world._pixlStore(PlayerSchema.self, PlayerGroup.self).metrics.activeCount, 1)
            XCTAssertEqual(world._pixlStore(EnemySchema.self, EnemyGroup.self).metrics.activeCount, enemyCount)
            XCTAssertEqual(world._pixlStore(BulletSchema.self, BulletGroup.self).metrics.activeCount, bulletCount)
        }
    }

    func testMeasureLargeWorldUpdate() {
        let world = makeLargeWorld()

        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            for enemy in world.entities.ofType(Enemy.self) {
                enemy.health += 1
                enemy.transform.position.x += 1
            }

            for bullet in world.entities.ofType(Bullet.self) {
                bullet.transform.position += bullet.velocity
                bullet.damage += 1
            }
        }
    }

    func testMeasureLargeWorldRead() {
        let world = makeLargeWorld()
        var sink = 0.0

        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            var local = 0.0

            for enemy in world.entities.ofType(Enemy.self) {
                local += Double(enemy.health)
                local += enemy.transform.position.x
            }

            for bullet in world.entities.ofType(Bullet.self) {
                local += Double(bullet.damage)
                local += bullet.velocity.y
            }

            sink = local
        }

        XCTAssertGreaterThan(sink, 0)
    }

    func testMeasureLargeWorldDespawn() {
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            let world = makeLargeWorld()
            let enemyIDs = Array(world.entities.ofType(Enemy.self).map(\.id))
            let bulletIDs = Array(world.entities.ofType(Bullet.self).map(\.id))

            for id in enemyIDs {
                world.despawn(id)
            }

            for id in bulletIDs {
                world.despawn(id)
            }

            XCTAssertEqual(world._pixlStore(EnemySchema.self, EnemyGroup.self).metrics.activeCount, 0)
            XCTAssertEqual(world._pixlStore(BulletSchema.self, BulletGroup.self).metrics.activeCount, 0)
        }
    }

    private func makeLargeWorld() -> Store {
        let world = Store()
        world.beginFrame()

        let player = world.spawn(Player.self)
        player.health = 10
        player.transform.position = Vec2(x: 100, y: 100)

        for index in 0..<enemyCount {
            let enemy = world.spawn(Enemy.self)
            enemy.health = 3
            enemy.transform.position = Vec2(x: Double(index), y: 10)
        }

        for index in 0..<bulletCount {
            let bullet = world.spawn(Bullet.self)
            bullet.damage = 1
            bullet.velocity = Vec2(x: 0, y: Double(index % 8) + 1)
            bullet.transform.position = Vec2(x: Double(index), y: 20)
        }

        return world
    }
}

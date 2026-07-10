import XCTest
import PixlStore

final class PixlStoreDirectStoragePerformanceTests: XCTestCase {
    private let enemyCount = 25_000
    private let bulletCount = 100_000

    func testMeasureDirectStorageAddLargeWorld() {
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            let world = Store()
            world.beginFrame()

            let player = world.spawn(Player.self)
            player.health += 10
            player.transform.position = Vec2(x: 100, y: 100)

            for index in 0..<enemyCount {
                let enemy = world.spawn(Enemy.self)
                enemy.health += 3
                enemy.transform.position = Vec2(x: Double(index), y: 10)
            }

            for index in 0..<bulletCount {
                let bullet = world.spawn(Bullet.self)
                bullet.damage += 1
                bullet.velocity = Vec2(x: 0, y: Double(index % 8) + 1)
                bullet.transform.position = Vec2(x: Double(index), y: 20)
            }

            XCTAssertEqual(world._pixlStore(PlayerSchema.self, PlayerGroup.self).metrics.activeCount, 1)
            XCTAssertEqual(world._pixlStore(EnemySchema.self, EnemyGroup.self).metrics.activeCount, enemyCount)
            XCTAssertEqual(world._pixlStore(BulletSchema.self, BulletGroup.self).metrics.activeCount, bulletCount)
            XCTAssertEqual(world._pixlStore(TransformSchema.self, TransformGroup.self).metrics.activeCount, 1 + enemyCount + bulletCount)
        }
    }

    func testMeasureDirectStorageReadLargeWorld() {
        let world = makeLargeWorld()
        var sink = 0.0

        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            var local = 0.0

            let playerStore = world._pixlStore(PlayerSchema.self, PlayerGroup.self)
            for row in 0..<playerStore.rowCount {
                guard playerStore.isActiveRow(row) else { continue }

                let player = Player(
                    id: playerStore.columns.entityID[row],
                    row: row,
                    frameID: world.currentFrameID,
                    storage: world
                )
                local += Double(player.health)
                local += player.transform.position.x
            }

            let enemyStore = world._pixlStore(EnemySchema.self, EnemyGroup.self)
            for row in 0..<enemyStore.rowCount {
                guard enemyStore.isActiveRow(row) else { continue }

                let enemy = Enemy(
                    id: enemyStore.columns.entityID[row],
                    row: row,
                    frameID: world.currentFrameID,
                    storage: world
                )
                local += Double(enemy.health)
                local += enemy.transform.position.x
            }

            let bulletStore = world._pixlStore(BulletSchema.self, BulletGroup.self)
            for row in 0..<bulletStore.rowCount {
                guard bulletStore.isActiveRow(row) else { continue }

                let bullet = Bullet(
                    id: bulletStore.columns.entityID[row],
                    row: row,
                    frameID: world.currentFrameID,
                    storage: world
                )
                local += Double(bullet.damage)
                local += bullet.velocity.y
                local += bullet.transform.position.x
            }

            sink = local
        }

        XCTAssertGreaterThan(sink, 0)
    }

    func testMeasureDirectStorageUpdateLargeWorld() {
        let world = makeLargeWorld()

        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            let playerStore = world._pixlStore(PlayerSchema.self, PlayerGroup.self)
            for row in 0..<playerStore.rowCount {
                guard playerStore.isActiveRow(row) else { continue }

                let player = Player(
                    id: playerStore.columns.entityID[row],
                    row: row,
                    frameID: world.currentFrameID,
                    storage: world
                )
                player.health += 10
                player.transform.position.x += 1
            }

            let enemyStore = world._pixlStore(EnemySchema.self, EnemyGroup.self)
            for row in 0..<enemyStore.rowCount {
                guard enemyStore.isActiveRow(row) else { continue }

                let enemy = Enemy(
                    id: enemyStore.columns.entityID[row],
                    row: row,
                    frameID: world.currentFrameID,
                    storage: world
                )
                enemy.health += 1
                enemy.transform.position.x += 1
            }

            let bulletStore = world._pixlStore(BulletSchema.self, BulletGroup.self)
            for row in 0..<bulletStore.rowCount {
                guard bulletStore.isActiveRow(row) else { continue }

                let bullet = Bullet(
                    id: bulletStore.columns.entityID[row],
                    row: row,
                    frameID: world.currentFrameID,
                    storage: world
                )
                bullet.transform.position += bullet.velocity
                bullet.damage += 1
            }
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

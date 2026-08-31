import Pixl
import Pixl2D

struct WorldBounds: Entity {
    private static let boundaryThickness: Float = 20
    private static let tileSize: Float = 20

    private let tile: Sprite

//    private var slope: Polygon

    private let rendering = RenderProperties(layer: .environment)

    let floor: Rect
    let ceiling: Rect
    let leftWall: Rect
    let rightWall: Rect
    let crouchPlatform: Rect
    let platforms: [Rect]
    private var movingPlatforms: [MovingPlatform]

    init(
        bounds: Rect,
        collisions: CollisionWorld2D,
        context: GameContext
    ) throws {
        let asset = try context.assets.load(texture: "world-platform")
        let sheet = SpriteSheet(asset: asset, columns: 2, rows: 2)
        tile = Sprite(region: sheet.region(column: 0, row: 0))

        let thickness = Self.boundaryThickness
        floor = Rect(
            x: bounds.minX,
            y: bounds.minY,
            width: bounds.width,
            height: thickness
        )
        ceiling = Rect(
            x: bounds.minX,
            y: bounds.maxY - thickness,
            width: bounds.width,
            height: thickness
        )
        leftWall = Rect(
            x: bounds.minX,
            y: bounds.minY,
            width: thickness,
            height: bounds.height
        )
        rightWall = Rect(
            x: bounds.maxX - thickness,
            y: bounds.minY,
            width: thickness,
            height: bounds.height
        )
        crouchPlatform = Rect(
            x: 80,
            y: floor.maxY + 20,
            width: 160,
            height: 16
        )
        platforms = [
            Rect(
                x: bounds.minX + 80,
                y: floor.maxY + 110,
                width: 180,
                height: 16
            ),
            Rect(
                x: bounds.maxX - 260,
                y: floor.maxY + 280,
                width: 180,
                height: 16
            ),
            Rect(
                x: bounds.minX + 120,
                y: floor.maxY + 440,
                width: 180,
                height: 16
            ),
            Rect(
                x: bounds.midX - 80,
                y: floor.maxY + 500,
                width: 160,
                height: 16
            ),
            Rect(
                x: bounds.midX - 80,
                y: floor.maxY + 80,
                width: 20,
                height: 330
            ),
            Rect(
                x: bounds.midX + 120,
                y: floor.maxY + 80,
                width: 20,
                height: 330
            ),
        ]
        movingPlatforms = [
            MovingPlatform(
                bounds: Rect(
                    x: bounds.maxX - 250,
                    y: floor.maxY + 100,
                    width: 160,
                    height: 16
                ),
                verticalTravel: 100,
                speed: 35,
                startsMovingUp: true,
                collisions: collisions
            ),
            MovingPlatform(
                bounds: Rect(
                    x: bounds.minX + 270,
                    y: floor.maxY + 280,
                    width: 160,
                    height: 16
                ),
                verticalTravel: 100,
                speed: 45,
                startsMovingUp: false,
                collisions: collisions
            ),
        ]

        insert(floor, into: collisions)
        insert(ceiling, into: collisions)
        insert(leftWall, into: collisions)
        insert(rightWall, into: collisions)
        insert(crouchPlatform, into: collisions)
        for platform in platforms {
            insert(platform, into: collisions)
        }

//        let asset = try context.assets.load(texture: "world")
//        let sheet = SpriteSheet(asset: asset, columns: 10, rows: 10)
//        let region = sheet.region(column: 0, row: 1)

//        slope = .init(
//            triangle: .init(800, 20),
//            paint: .texture(.init(region: region))
//        )
    }

//    var slopeGeometry: Polygon2D { slope.geometry }
//
//    var slopeTransform: Transform2D {
//        .init(floor.center).scaled(x: -1, y: 1)
//    }

    func submit(to queue: RenderQueue, context: GameContext) {
        submit(leftWall, to: queue)
        submit(rightWall, to: queue)
        submit(floor, to: queue)
        submit(ceiling, to: queue)
        submit(crouchPlatform, to: queue)
        for platform in platforms {
            submit(platform, to: queue)
        }
        for platform in movingPlatforms {
            submit(platform.bounds, to: queue)
        }

//        queue.submit(
//            slope,
//            transform: slopeTransform,
//            rendering: rendering
//        )
    }

    mutating func fixedUpdate(
        delta: Float,
        collisions: CollisionWorld2D
    ) {
        for index in movingPlatforms.indices {
            movingPlatforms[index].fixedUpdate(
                delta: delta,
                collisions: collisions
            )
        }
    }

    private func submit(_ bounds: Rect, to queue: RenderQueue) {
        let columns = max(
            1,
            Int((bounds.width / Self.tileSize).rounded(.up))
        )
        let rows = max(
            1,
            Int((bounds.height / Self.tileSize).rounded(.up))
        )
        let size = Vec2(
            bounds.width / Float(columns),
            bounds.height / Float(rows)
        )
        let scale = size / tile.size

        for row in 0..<rows {
            for column in 0..<columns {
                let center = bounds.origin + Vec2(
                    (Float(column) + 0.5) * size.x,
                    (Float(row) + 0.5) * size.y
                )
                queue.submit(
                    tile,
                    transform: .init(center, scale: scale),
                    rendering: rendering
                )
            }
        }
    }

    private func insert(
        _ bounds: Rect,
        into collisions: CollisionWorld2D
    ) {
        collisions.insert(
            bounds: bounds,
            mode: .static,
            layer: .world,
            mask: .none
        )
    }
}

import Pixl
import Pixl2D

struct WorldBounds: Entity {
    private static let boundaryThickness: Float = 20

    private let shape = Shape(.rect)
        .fill(.gray6)

//    private var slope: Polygon

    private let rendering = RenderProperties(layer: .environment)

    let floor: Rect
    let leftWall: Rect
    let rightWall: Rect
    let crouchPlatform: Rect

    init(bounds: Rect, context: GameContext) throws {
        let thickness = Self.boundaryThickness
        floor = Rect(
            x: bounds.minX,
            y: bounds.minY,
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
        submit(crouchPlatform, to: queue)

//        queue.submit(
//            slope,
//            transform: slopeTransform,
//            rendering: rendering
//        )
    }

    private func submit(_ bounds: Rect, to queue: RenderQueue) {
        queue.submit(
            shape,
            transform: .init(bounds.center, scale: bounds.size),
            rendering: rendering
        )
    }
}

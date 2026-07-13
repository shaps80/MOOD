import Pixl
import Pixl2D

struct Player: Entity {
    private let triangle: Triangle
    private let pipeline: RenderPipeline

    private let camera = OrthographicCamera(halfHeight: 25)
    private var rotation: Double = .zero
    private let rotationSpeed = Double.random(in: -2...2)
    private let position = Vec2.random(
        x: -49...49,
        y: -24...24
    )


    init(context: GameContext) throws {
        triangle = try Triangle(device: context.platform.device)
        pipeline = try context.platform.device.makeRenderPipeline(
            .init(
                vertex: Shaders.vertex,
                fragment: Shaders.fragment,
                vertexLayout: ColorGeometry.vertexLayout,
                colorFormat: context.renderSettings.drawableFormat
            )
        )
    }

    mutating func update(
        entity: EntityID,
        in world: World,
        time: UpdateTime,
        lanes: Lanes
    ) {
        rotation = time.elapsedSeconds * rotationSpeed
    }

    func render(
        entity: EntityID,
        in world: World,
        output: RenderTarget,
        on pass: RenderPassEncoder,
        time: RenderTime
    ) throws {
        pass.setRenderPipeline(pipeline)
        triangle.draw(
            on: pass,
            transform: camera
                .projection(for: output)
                .translated(by: position)
                .rotated(by: rotation)
        )
    }
}

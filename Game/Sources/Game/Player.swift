import Pixl
import Pixl2D

struct Player: Entity {
    private let triangle: Triangle
    private let pipeline: RenderPipeline
    private let camera = OrthographicCamera()
    private var rotation = 0.0

    init(device: any Device, drawableFormat: PixelFormat) throws {
        triangle = try Triangle(device: device)
        pipeline = try device.makeRenderPipeline(
            .init(
                vertex: Shaders.vertex,
                fragment: Shaders.fragment,
                vertexLayout: ColorGeometry.vertexLayout,
                colorFormat: drawableFormat
            )
        )
    }

    mutating func update(
        entity: EntityID,
        in world: World,
        time: UpdateTime,
        lanes: Lanes
    ) {
        rotation = time.elapsedSeconds
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
            transform: camera.projection(for: output).rotated(by: rotation)
        )
    }
}

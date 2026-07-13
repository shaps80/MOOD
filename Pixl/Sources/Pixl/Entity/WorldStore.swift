import PixlConcurrency
import PixlPlatform

protocol WorldStore: AnyObject {
    var valueType: Any.Type { get }

    func fixedUpdate(in world: World, time: FixedTime, lanes: Lanes)
    func update(in world: World, time: UpdateTime, lanes: Lanes)

    func render(
        in world: World,
        output: RenderTarget,
        on pass: RenderPassEncoder,
        time: RenderTime
    ) throws
}

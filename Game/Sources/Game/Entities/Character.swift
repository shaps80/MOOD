import Pixl
import Pixl2D

struct Character: Entity {
    private var sprite: Sprite
    private let sheet: SpriteSheet

    private let idle: SpriteAnimation
    private let walk: SpriteAnimation
    private var timeline: SpriteAnimation.Timeline

    private var position: Vec2 = .zero
    private var rotation: Float = .pi / 4
    private var velocity: Vec2 = .zero
    private let camera: OrthographicCamera
    private var isSelected: Bool = false
    private var isDragging: Bool = false

    var bounds: Rect {
        .init(center: .zero, size: sprite.size)
    }

    private var transform: Transform2D {
        Transform2D(position).rotated(by: rotation)
    }

    private let bindings: PlayerBindings = .init()
    private let controller: AxisController = .init(
        maxSpeed: 300,
        acceleration: 1000,
        deceleration: 1000
    )

    init(
        camera: OrthographicCamera,
        context: GameContext
    ) throws {
        self.camera = camera

        sprite = try .init(
            named: "character.png",
            context: context
        )

        sheet = SpriteSheet(
            asset: sprite.asset,
            columns: 3,
            rows: 4
        )

        idle = .init(
            frames: sheet[row: 0, columns: ...1],
            frameDuration: 0.3
        )

        walk = .init(
            frames: sheet[row: 2],
            frameDuration: 0.2
        )

        timeline = .init(animation: idle)
        sprite.region = timeline.region
        sprite.layer = .entity

        bindings.bind(to: context.inputs)
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        timeline.advance(by: time.delta)
        sprite.region = timeline.region

        let target = bindings.velocity

        velocity = controller.velocity(
            source: velocity,
            target: target,
            delta: time.delta
        )

        position += velocity * Float(time.delta)

        if velocity.x > 0 {
            sprite.isFlipped = false
            timeline.animation = walk
        } else if velocity.x < 0 {
            sprite.isFlipped = true
            timeline.animation = walk
        } else {
            timeline.animation = idle
        }

        let world = context.coordinates(for: .world(camera))
        let local = world.coordinates(relativeTo: transform)
        
        if let event = context.mouse.event(.primary, phase: .down) {
            if bounds.contains(local.location(for: event)) {
                isSelected = true
                isDragging = true
            } else {
                isSelected = false
            }
        }

        if isDragging && context.mouse.isPressed(.primary) {
            position += world.translation(for: context.mouse)
        }

        if context.mouse.wasReleased(.primary) {
            isDragging = false
        }

        if isSelected {
            for event in context.mouse.scrollEvents {
                let scale: Float = switch event.unit {
                case .pixel: 0.002
                case .line: 0.1
                case .page: 0.5
                }
                rotation -= event.translation.y * scale
            }
        }
    }

    func submit(to queue: RenderQueue, context: GameContext) {
        queue.submit(
            sprite,
            transform: transform
        )

        if isSelected {
            context.draw(
                .rect(
                    .init(
                        x: 0,
                        y: -0.5,
                        width: sprite.size.x * 0.5,
                        height: 1
                    )
                ),
                transform: transform,
                style: .fill(.red),
                layer: .gizmo
            )

            context.draw(
                .rect(
                    .init(
                        x: -0.5,
                        y: 0,
                        width: 1,
                        height: sprite.size.y * 0.5
                    )
                ),
                transform: transform,
                style: .fill(.green),
                layer: .gizmo
            )

            context.draw(
                .ellipse(
                    in: .init(
                        center: .zero,
                        size: bounds.size
                    )
                ),
                transform: transform,
                style: .stroke(.fill, width: 1),
                layer: .gizmo
            )

            let markerCenter = Vec2(sprite.size.x * 0.5, 0)
            let markerSize: Float = 4

            context.draw(
                .ellipse(in: .init(center: markerCenter, size: .init(repeating: markerSize))),
                transform: transform,
                style: .fill(.yellow),
                layer: .gizmo
            )
        }
    }

}

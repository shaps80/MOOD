import Pixl
import Pixl2D

struct Editable {
    var position: Vec2
    var rotation: Float
    var size: Vec2

    private var isSelected = false
    private var isDragging = false

    init(
        position: Vec2 = .zero,
        rotation: Float = 0,
        size: Vec2 = .zero
    ) {
        self.position = position
        self.rotation = rotation
        self.size = size
    }

    var transform: Transform2D {
        Transform2D(position).rotated(by: rotation)
    }

    mutating func update<Camera: Camera2D>(
        camera: Camera,
        context: GameContext
    ) {
        let world = context.coordinates(for: .world(camera))
        let local = world.coordinates(relativeTo: transform)
        let bounds = Rect(center: .zero, size: size)

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

    func drawGizmo(context: GameContext) {
        guard isSelected else { return }

        context.draw(
            .rect(
                .init(
                    x: 0,
                    y: -0.5,
                    width: size.x * 0.5,
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
                    height: size.y * 0.5
                )
            ),
            transform: transform,
            style: .fill(.green),
            layer: .gizmo
        )

        context.draw(
            .rect(.init(center: .zero, size: size)),
            transform: transform,
            style: .stroke(.fill, width: 1),
            layer: .gizmo
        )

        let markerCenter = Vec2(size.x * 0.5, 0)
        let markerSize: Float = 4

        context.draw(
            .ellipse(
                in: .init(
                    center: markerCenter,
                    size: .init(repeating: markerSize)
                )
            ),
            transform: transform,
            style: .fill(.yellow),
            layer: .gizmo
        )
    }
}

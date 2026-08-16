import PixlRenderer
import Swift

@MainActor
public final class Renderer {
    private let renderer: PixlRenderer.Renderer
    private var stateSystem: ObjectIdentifier?
    private var stateTick: UInt64?

    public init(backend: any Backend) {
        renderer = .init(backend: backend)
    }

    public func render(
        _ system: System,
        interpolation: Float,
        tick: UInt64,
        viewProjection: Matrix4x4
    ) throws {
        let systemID = ObjectIdentifier(system)
        let positionsChanged = stateSystem != systemID || stateTick != tick
        if positionsChanged {
            stateSystem = systemID
            stateTick = tick
        }

        try system.withPositions { previous, current, count in
            try renderer.render(
                previous: previous,
                current: current,
                count: count,
                positionsChanged: positionsChanged,
                interpolation: interpolation,
                viewProjection: viewProjection
            )
        }
    }
}

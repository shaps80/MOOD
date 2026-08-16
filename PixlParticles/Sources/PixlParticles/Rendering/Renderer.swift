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
        viewProjection: Matrix4x4,
        viewport: ViewportSize
    ) throws {
        let systemID = ObjectIdentifier(system)
        let positionsChanged = stateSystem != systemID || stateTick != tick
        let idsChanged = stateSystem != systemID
        if positionsChanged {
            stateSystem = systemID
            stateTick = tick
        }

        try system.withRenderingData { previous, current, ids, count in
            try renderer.render(
                previous: previous,
                current: current,
                ids: ids,
                count: count,
                positionsChanged: positionsChanged,
                idsChanged: idsChanged,
                interpolation: interpolation,
                viewProjection: viewProjection,
                viewport: viewport
            )
        }
    }
}

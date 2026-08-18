import PixlRenderer
import Swift

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
        cullingViewProjection: Matrix4x4,
        viewProjection: Matrix4x4,
        viewport: ViewportSize
    ) throws {
        let systemID = ObjectIdentifier(system)
        let positionsChanged = stateSystem != systemID || stateTick != tick
        let colorsChanged = positionsChanged
        let idsChanged = stateSystem != systemID
        stateSystem = systemID
        stateTick = tick

        try system.withRenderingData {
            previousPositions,
            currentPositions,
            previousColors,
            currentColors,
            ids,
            count in
            try renderer.render(
                previous: previousPositions,
                current: currentPositions,
                ids: ids,
                count: count,
                positionsChanged: positionsChanged,
                colorsChanged: colorsChanged,
                idsChanged: idsChanged,
                interpolation: interpolation,
                cullingViewProjection: cullingViewProjection,
                viewProjection: viewProjection,
                viewport: viewport,
                writePreviousColors: { destination in
                    destination.copyMemory(
                        from: UnsafeRawBufferPointer(previousColors)
                    )
                },
                writeCurrentColors: { destination in
                    destination.copyMemory(
                        from: UnsafeRawBufferPointer(currentColors)
                    )
                }
            )
        }
    }
}

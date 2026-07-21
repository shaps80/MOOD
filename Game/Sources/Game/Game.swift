import Pixl
import Pixl2D

@main
struct Game: Pixl.Game {
    private var player: Player
    private var camera: OrthographicCamera = .init(halfHeight: 200)
    private let cameraBindings: CameraBindings = .init()
//    private var shapeCatalogue: ShapeCatalogue
//    private var gameState: GameStateHandler

    init(context: GameContext) throws {
//        self.gameState = try .init(context: context)
        player = try Player(
            count: 100_000,
            worldSize: 10_000,
            context: context
        )
        cameraBindings.bind(to: context.inputs)

//        self.shapeCatalogue = .init(context: context)
    }

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime,
        context: GameContext
    ) throws {
//        shapeCatalogue.submit(to: context.renderQueue)

        let spatialStart = ContinuousClock.now
        let submittedCount = player.submit(
            visibleBounds: camera.visibleBounds(for: output),
            to: context.renderQueue
        )
        let spatialSeconds = Self.seconds(spatialStart.duration(to: .now))

        try context.render(
            through: camera,
            to: output,
            frame: frame,
            clear: .white
        )

        logMetrics(
            time,
            spatialSeconds: spatialSeconds,
            submittedCount: submittedCount
        )
    }

    mutating func didEnter(_ phase: GamePhase, context: GameContext) {
//        gameState.didEnter(phase, context: context)
    }

    mutating func fixedUpdate(_ time: FixedTime, context: GameContext) {
        player.fixedUpdate(time, context: context)
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        player.update(time, context: context)
        camera.center += cameraBindings.direction * (600 * time.delta)

//        gameState.update(time, context: context)
//        shapeCatalogue.update(time, context: context)
    }

    private func logMetrics(
        _ time: RenderTime,
        spatialSeconds: Double,
        submittedCount: Int
    ) {
        let interval = UInt64(Self.gameSettings.preferredFps * 5)
        guard time.frameIndex > 0,
            time.frameIndex.isMultiple(of: interval)
        else {
            return
        }
        print(time.metrics.summary)
        print(
            "Spatial grid: \(spatialSeconds * 1_000)ms | "
                + "Submitted: \(submittedCount)"
        )
    }

    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }
}

import PixlPlatform
extension Game {
    static var gameSettings: GameSettings {
        .init(
            title: "Pixl",
            resolution: .init(x: 1200, y: 600),
        )
    }

    static let assetSettings: AssetSettings = .init()

    static var renderSettings: RenderSettings {
        .init(
            framePassCapacity: 1,
            frameCommandCapacity: 16,
            frameByteCapacity: 128 * 1024,
            bufferCapacity: 4,
            pipelineCapacity: 2,
            samplerCapacity: 2,
            textureCapacity: 4,
            drawableCapacity: 1
        )
    }

    static var renderQueueSettings: RenderQueue.Settings {
        .init(
            capacity: 4096,
            viewCapacity: 1,
            gradientCapacity: 1
        )
    }
}

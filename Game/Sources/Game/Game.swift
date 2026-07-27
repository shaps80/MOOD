import Pixl
import Pixl2D
import PixlUI

@main
struct Game: Pixl.Game {
    private var player: Character
    private var camera: OrthographicCamera = .init(halfHeight: 200)
//    private let cameraBindings: CameraBindings = .init()
    private let hud = Scene(HUD())
    private var shapeCatalogue: ShapeCatalogue
//    private var gameState: GameStateHandler

    init(context: GameContext) throws {
//        self.gameState = try .init(context: context)
//        cameraBindings.bind(to: context.inputs)

        player = try .init(context: context)
        shapeCatalogue = .init(context: context)

    }

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime,
        context: GameContext
    ) throws {
        let pixels = output.texture.descriptor.size
        shapeCatalogue.submit(
            to: context.renderQueue,
            in: .init(
                width: Float(pixels.width) / context.displayScale,
                height: Float(pixels.height) / context.displayScale
            )
        )

        context.clear(
            target: output,
            color: .white,
            frame: frame
        )

        try context.render(
            to: output,
            frame: frame
        )

        player.submit(to: context.renderQueue)

        try context.render(
            through: camera,
            to: output,
            frame: frame
        )

        try context.render(
            scene: hud,
            to: output,
            frame: frame
        )

        logMetrics(time: time)
    }

    mutating func didEnter(_ phase: GamePhase, context: GameContext) {
//        gameState.didEnter(phase, context: context)
    }

    mutating func fixedUpdate(_ time: FixedTime, context: GameContext) {
        player.fixedUpdate(time, context: context)
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        player.update(time, context: context)
//        camera.center += cameraBindings.direction * (600 * Float(time.delta))

//        gameState.update(time, context: context)
        shapeCatalogue.update(time, context: context)
    }

    private func logMetrics(time: RenderTime) {
        let interval = UInt64(Self.gameSettings.preferredFps * 5)
        guard time.frameIndex > 0,
            time.frameIndex.isMultiple(of: interval)
        else {
            return
        }
        print(time.metrics.summary)
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
            preferredFps: 60,
            resolution: .init(x: 1200, y: 600),
        )
    }

    static let assetSettings: AssetSettings = .init()

//    static var renderSettings: RenderSettings {
//        .init(
//            frameCommandCapacity: 16,
//            frameByteCapacity: 128 * 1024,
//            bufferCapacity: 4,
//            pipelineCapacity: 2,
//            samplerCapacity: 2,
//            textureCapacity: 4,
//            drawableCapacity: 1
//        )
//    }
//
//    static var renderQueueSettings: RenderQueue.Settings {
//        .init(
//            capacity: 4_096,
//            viewCapacity: 1,
//            gradientCapacity: 1
//        )
//    }
}

/*

 100K instances - 180MB - 9% - Double

 FPS: 59.950383563803 | Frame avg: 16.68046041666667ms | Frame max: 17.658875000000002ms
 Game avg: 0.0022257500000000003ms | Render avg: 0.2719860166666667ms
 Render queue | Lowering: 0.12356458333333344ms | Culling: 0.010197916666666666ms
 Layer binning: 0.0061174166666666694ms | Ordering: 0.00018891666666666674ms
 Batching: 0.0030325666666666676ms | Instances: 0.006139633333333337ms
 Spatial grid: 0.136375ms | Submitted: 1340

 1M instances - 240MB - 24% - Double

 FPS: 60.00055816256943 | Frame avg: 16.666511622950818ms | Frame max: 17.744167ms
 Game avg: 0.0024439508196721317ms | Render avg: 1.6633606065573774ms
 Render queue | Lowering: 0.8004105573770492ms | Culling: 0.07112904918032788ms
 Layer binning: 0.032339426229508215ms | Ordering: 0.0004637704918032788ms
 Batching: 0.02064752459016394ms | Instances: 0.04470016393442625ms
 Spatial grid: 0.531792ms | Submitted: 13766

 1M instances - 225MB - 22% - Float

 FPS: 59.955348254387545 | Frame avg: 16.679079166666668ms | Frame max: 17.603ms
 Game avg: 0.0013374833333333331ms | Render avg: 2.6518784666666653ms
 Render queue | Lowering: 1.2951263499999999ms | Culling: 0.08978676666666668ms
 Layer binning: 0.05150004999999999ms | Ordering: 0.00042158333333333327ms
 Batching: 0.029483266666666674ms | Instances: 0.048979083333333354ms
 Spatial grid: 0.651791ms | Submitted: 14025

 */

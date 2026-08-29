import Pixl
import Pixl2D
import PixlUI

@main
struct Game: Pixl.Game {
    private var player: Character
    private var camera: OrthographicCamera = .init(halfHeight: 200)

//    private let debug = Scene(Debug())
//    private var shapeCatalogue: ShapeCatalogue
//    private var gameState: GameStateHandler

    init(context: GameContext) throws {
//        self.gameState = try .init(context: context)
//        shapeCatalogue = .init(context: context)
        player = try .init(context: context)
    }

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime,
        context: GameContext
    ) throws {
//        let pixels = output.texture.descriptor.size
//        let screenSpace = context.screenSpace
//        shapeCatalogue.submit(
//            to: screenSpace,
//            in: .init(
//                width: Float(pixels.width) / context.displayScale,
//                height: Float(pixels.height) / context.displayScale
//            )
//        )

        context.clear(
            target: output,
            color: .black,
            frame: frame
        )

//        try context.render(
//            screenSpace,
//            to: output,
//            frame: frame
//        )

        player.submit(to: context.renderQueue)

        try context.render(
            through: camera,
            to: output,
            frame: frame
        )

//        try context.render(
//            scene: debug,
//            to: output,
//            frame: frame
//        )

        logMetrics(time: time)
    }

    mutating func didEnter(_ phase: GamePhase, context: GameContext) {
//        gameState.didEnter(phase, context: context)
    }

    mutating func fixedUpdate(_ time: FixedTime, context: GameContext) {
        player.fixedUpdate(time, context: context)
    }
//
    mutating func update(_ time: UpdateTime, context: GameContext) {
        player.update(time, context: context)

        _ = context.mouse.location(in: .screen)
//        gameState.update(time, context: context)
//        shapeCatalogue.update(time, context: context)
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
}

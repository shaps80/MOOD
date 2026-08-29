import Pixl
import Pixl2D
import PixlUI

@main
struct Game: Pixl.Game {
    private let worldBounds = WorldBounds()
    private var character: Character
    private var camera: OrthographicCamera = .init(halfHeight: 200)

//    private let debug = Scene(Debug())
//    private var gameState: GameStateHandler

    init(context: GameContext) throws {
//        self.gameState = try .init(context: context)
        character = try .init(camera: camera, context: context)
    }

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime,
        context: GameContext
    ) throws {
        context.clear(
            target: output,
            color: .black,
            frame: frame
        )

        worldBounds.submit(
            to: context.renderQueue,
            context: context
        )

        character.submit(
            to: context.renderQueue,
            context: context
        )

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
        character.fixedUpdate(time, context: context)
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        character.update(time, context: context)
//        gameState.update(time, context: context)
    }

    private func logMetrics(time: RenderTime) {
        let interval = UInt64(Self.gameSettings.preferredFps * 5)
        guard time.frameIndex > 0,
            time.frameIndex.isMultiple(of: interval)
        else {
            return
        }
//        print(time.metrics.summary)
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

import Pixl
import Pixl2D

@main
struct Game: Pixl.Game {
    private var players: [Player]
    private let camera: OrthographicCamera = .init(halfHeight: 200)
//    private var shapeCatalogue: ShapeCatalogue
//    private var gameState: GameStateHandler

    init(context: GameContext) throws {
//        self.gameState = try .init(context: context)
        players = try (0..<1_000).map { _ in
            try Player(position: .init(
                Double.random(in: -376...376),
                Double.random(in: -176...176)
            ), context: context)
        }

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

        players.forEach {
            $0.submit(to: context.renderQueue)
        }

        try context.render(
            through: camera,
            to: output,
            frame: frame,
            clear: .black
        )

        logMetrics(time)
    }

    mutating func didEnter(_ phase: GamePhase, context: GameContext) {
//        gameState.didEnter(phase, context: context)
    }

    mutating func fixedUpdate(_ time: FixedTime, context: GameContext) {
        players.indices.forEach {
            players[$0].fixedUpdate(time, context: context)
        }
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        players.indices.forEach {
            players[$0].update(time, context: context)
        }

//        gameState.update(time, context: context)
//        shapeCatalogue.update(time, context: context)
    }

    private func logMetrics(_ time: RenderTime) {
        let interval = UInt64(Self.gameSettings.preferredFps * 5)
        guard time.frameIndex > 0,
            time.frameIndex.isMultiple(of: interval)
        else {
            return
        }
        print(time.metrics.summary)
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
}

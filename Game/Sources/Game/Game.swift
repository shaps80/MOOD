import Pixl
import Pixl2D

@main
struct Game: Pixl.Game {
    private var entities: [Entity]
    private let camera: OrthographicCamera = .init()
    private var shapeCatalogue: ShapeCatalogue
    private var gameState: GameStateHandler

    init(context: GameContext) throws {
        self.gameState = try .init(context: context)
        self.entities = try [
            Player(context: context),
            Character(context: context)
        ]
        self.shapeCatalogue = .init(context: context)
    }

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime,
        context: GameContext
    ) throws {
        shapeCatalogue.submit(to: context.renderQueue)

        try context.render(
            through: camera,
            to: output,
            frame: frame,
            clear: .black
        )

        logMetrics(time)
    }

    mutating func didEnter(_ phase: GamePhase, context: GameContext) {
        gameState.didEnter(phase, context: context)
    }

    mutating func fixedUpdate(_ time: FixedTime, context: GameContext) {
        entities.indices.forEach {
            entities[$0].fixedUpdate(time, context: context)
        }
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        entities.indices.forEach {
            entities[$0].update(time, context: context)
        }

        gameState.update(time, context: context)
        shapeCatalogue.update(time, context: context)
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

extension Game {
    static var gameSettings: GameSettings {
        .init(
            title: "Pixl",
            resolution: .init(x: 320, y: 180),
        )
    }

    static let assetSettings: AssetSettings = .init()
}

import Pixl
import Pixl2D
import PixlUI

@main
struct Game: Pixl.Game {
    private let worldBounds = WorldBounds()
    private let collisions: CollisionWorld2D
    private let characterCollider: ColliderID
    private var character: Character
    private var camera: OrthographicCamera = .init(halfHeight: 200)

//    private let debug = Scene(Debug())
//    private var gameState: GameStateHandler

    init(context: GameContext) throws {
//        self.gameState = try .init(context: context)
        let collisions = CollisionWorld2D()
        let character = try Character(camera: camera, context: context)
        characterCollider = collisions.insert(
            bounds: character.bounds,
            mode: .dynamic,
            layer: .character,
            mask: .world
        )
        _ = collisions.insert(
            bounds: worldBounds.floor,
            mode: .static,
            layer: .world,
            mask: .none
        )
        _ = collisions.insert(
            bounds: worldBounds.leftWall,
            mode: .static,
            layer: .world,
            mask: .none
        )
        _ = collisions.insert(
            bounds: worldBounds.rightWall,
            mode: .static,
            layer: .world,
            mask: .none
        )
        self.collisions = collisions
        self.character = character
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
        collisions.update(characterCollider, bounds: character.bounds)
        collisions.advance()
        collisions.forEachCollision { collision in
            guard collision.source.collider == characterCollider else { return }
            character.onCollision(collision, context: context)
        }
        collisions.update(characterCollider, bounds: character.bounds)
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

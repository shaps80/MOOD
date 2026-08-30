import Pixl
import Pixl2D
import PixlUI

@main
struct Game: Pixl.Game {
    private let worldBounds: WorldBounds
    private let collisions: CollisionWorld2D
    private let bindings: GameBindings = .init()
    private var character: Character
    private var showsCollisionDebug = false
    private var camera: OrthographicCamera

//    private let debug = Scene(Debug())
//    private var gameState: GameStateHandler

    init(context: GameContext) throws {
        let camera = OrthographicCamera(
            halfHeight: Character.referenceCameraHalfHeight
        )
        self.camera = camera
        let resolution = Self.gameSettings.resolution
        let viewportSize = Vec2(
            Float(resolution.x),
            Float(resolution.y)
        )
        self.worldBounds = try .init(
            bounds: camera.visibleBounds(in: viewportSize),
            context: context
        )
//        self.gameState = try .init(context: context)
        let collisions = CollisionWorld2D()
        let character = try Character(
            camera: camera,
            collisions: collisions,
            context: context
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
        _ = collisions.insert(
            bounds: worldBounds.crouchPlatform,
            mode: .static,
            layer: .world,
            mask: .none
        )
        bindings.bind(to: context.inputs)
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
            showsCollisionDebug: showsCollisionDebug,
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
        character.fixedUpdate(
            time,
            collisions: collisions,
            context: context
        )
        collisions.advance { collision in
            character.onCollision(
                collision,
                context: context
            )
        }
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        if bindings.collisionDebug.is(.down) {
            showsCollisionDebug.toggle()
        }
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
    static let loopSettings = LoopSettings(
        fixedStep: .init(
            updatesPerSecond: 60,
            maximumUpdatesPerFrame: 8
        )
    )

    static var gameSettings: GameSettings {
        .init(
            title: "Pixl",
            preferredFps: 60,
            resolution: .init(x: 1200, y: 600),
        )
    }

    static let assetSettings: AssetSettings = .init()
}

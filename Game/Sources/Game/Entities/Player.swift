import Pixl
import Pixl2D

struct Player: Entity {
    private let quad: Quad
    private let pipeline: RenderPipeline
    private let sampler: Sampler
    private let texture: TextureAsset?
    private let jump: SoundAsset?

    private let camera = OrthographicCamera(halfHeight: 1)
    private var rotation: Double = .zero
    private var nextJumpSoundElapsed = Double.pi
    private let position = Vec2.zero

    init(
        pipeline: RenderPipeline,
        context: GameContext
    ) throws {
        texture = context.assets.load(texture: "player.png")
        jump = context.assets.load(sound: "jump.wav")
        quad = try .init(
            device: context.platform.device,
            color: .clear
        )
        self.pipeline = pipeline
        sampler = try context.platform.device.makeSampler(.init())
    }

    mutating func update(_ time: UpdateTime, context: GameContext) {
        rotation = -time.elapsedSeconds

        if let jump, time.elapsedSeconds >= nextJumpSoundElapsed {
            context.audio.play(jump)
        }

        let fullTurn = Double.pi * 2
        let completedMarkers = (
            (time.elapsedSeconds - Double.pi) / fullTurn
        ).rounded(.down) + 1
        nextJumpSoundElapsed = Double.pi + completedMarkers * fullTurn
    }

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime,
        context: GameContext
    ) throws {
        let pass = frame.beginRenderPass(
            .init(.init(target: output, loadAction: .load))
        )

        pass.setRenderPipeline(pipeline)
        if let texture {
            pass.setFragmentTexture(texture, index: 0)
        }
        pass.setFragmentSampler(sampler, index: 0)
        quad.draw(
            on: pass,
            transform: camera
                .projection(for: output)
                .translated(by: position)
//                .scaled(x: -1, y: 1) // flip horizontally
                .rotated(by: rotation)
        )
    }
}

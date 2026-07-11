import Pixl

@main
struct Game: Pixl.Game {
    func render(on platform: any Platform) throws {
        guard let drawable = platform.drawable() else { return }

        let frame = Frame(
            passes: [
                .render(
                    RenderPass(
                        ColorAttachment(
                            target: .init(texture: drawable.texture),
                            loadAction: .clear(.red)
                        )
                    )
                )
            ]
        )

        try platform.present(frame, to: consume drawable)
    }
}

import Pixl

@main
struct Game: Pixl.Game {
    func render(
        on platform: any Platform,
        output: RenderTarget
    ) throws -> Frame {
        Frame(
            passes: [
                .render(
                    RenderPass(
                        ColorAttachment(
                            target: output,
                            loadAction: .clear(.red)
                        )
                    )
                )
            ]
        )
    }
}

import Pixl

@main
struct Game: Pixl.Game {
    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame
    ) throws {
        frame.append(
            .render(
                RenderPass(
                    ColorAttachment(
                        target: output,
                        loadAction: .clear(.red)
                    )
                )
            )
        )
    }
}

import Pixl

@main
struct Game: Pixl.Game {
    static var gameSettings: GameSettings {
        .init(
            title: "Testing",
            resolution: .init(
                width: 800,
                height: 400
            )
        )
    }

    init(platform: any Platform) throws {}

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

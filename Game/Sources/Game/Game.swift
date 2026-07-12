import Foundation
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

    private var shaderLibrary: (any ShaderLibrary)?
    mutating func setup(on platform: any Platform) throws {
        guard let url = Bundle.module.url(
            forResource: "PixlBuiltIn",
            withExtension: "metallib"
        ) else {
            fatalError("Generated Metal shader library is missing")
        }

        let data = try Data(contentsOf: url)
        let shader = data.withUnsafeBytes {
            Shader(copying: $0)
        }
        shaderLibrary = try platform.device.makeShaderLibrary(shader)
    }

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

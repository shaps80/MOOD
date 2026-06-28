import Pixl
import JavaScriptKit
import Swift

extension Renderer {
    func configureCanvas() {
        let document = JSObject.global.document
        installDocumentStyles(in: document)

        let canvas = document.getElementById("game").object ?? createCanvas(in: document)
        self.canvas = canvas
        configureCanvasElement(canvas)
    }

    private func installDocumentStyles(in document: JSValue) {
        guard document.getElementById("mood-runtime-style").object == nil else { return }
        guard let style = document.createElement("style").object else {
            fatalError("Unable to create runtime style element")
        }
        guard let head = document.head.object else {
            fatalError("Missing document head")
        }

        style.id = "mood-runtime-style"
        style.textContent = (
            """
            html,
            body {
                margin: 0;
                width: 100%;
                height: 100%;
                display: grid;
                place-items: center;
                background: #000;
            }

            #game {
                display: block;
                touch-action: none;
                user-select: none;
                -webkit-user-select: none;
                -webkit-tap-highlight-color: transparent;
            }
            """
        )
        _ = head.appendChild!(style)
    }

    private func createCanvas(in document: JSValue) -> JSObject {
        guard let canvas = document.createElement("canvas").object else {
            fatalError("Unable to create canvas element")
        }
        guard let body = document.body.object else {
            fatalError("Missing document body")
        }

        canvas.id = "game"
        _ = body.appendChild!(canvas)

        return canvas
    }

    private func configureCanvasElement(_ canvas: JSObject) {
        canvas.style.touchAction = .string("none")
        canvas.style.userSelect = .string("none")
        canvas.style.webkitUserSelect = .string("none")
        canvas.style.webkitTapHighlightColor = .string("transparent")
    }

    func syncCanvasWithGameResolution(game: Game) {
        guard let canvas, let gl else { return }
        let displaySize = canvasDisplaySize(game: game)

        guard displaySize != lastCanvasDisplaySize else {
            return
        }

        if canvas.width.number != displaySize.backingWidth {
            canvas.width = .number(displaySize.backingWidth)
        }

        if canvas.height.number != displaySize.backingHeight {
            canvas.height = .number(displaySize.backingHeight)
        }

        canvas.style.imageRendering = .string("auto")
        canvas.style.width = .string("\(displaySize.displayWidth)px")
        canvas.style.height = .string("\(displaySize.displayHeight)px")
        _ = gl.viewport!(0, 0, displaySize.backingWidth, displaySize.backingHeight)
        lastCanvasDisplaySize = displaySize
    }

    func canvasDisplaySize(game: Game) -> CanvasDisplaySize {
        let viewportWidth = JSObject.global.innerWidth.number ?? game.logicalResolution.x
        let viewportHeight = JSObject.global.innerHeight.number ?? game.logicalResolution.y
        let scale = displayScale(viewportWidth: viewportWidth, viewportHeight: viewportHeight, game: game)
        let displayWidth = game.logicalResolution.x * scale
        let displayHeight = game.logicalResolution.y * scale
        let devicePixelRatio = max(1, JSObject.global.devicePixelRatio.number ?? 1)
        let backingWidth = max(1, (displayWidth * devicePixelRatio).rounded())
        let backingHeight = max(1, (displayHeight * devicePixelRatio).rounded())

        return CanvasDisplaySize(
            displayWidth: displayWidth,
            displayHeight: displayHeight,
            backingWidth: backingWidth,
            backingHeight: backingHeight
        )
    }

    private func displayScale(
        viewportWidth: Double,
        viewportHeight: Double,
        game: Game
    ) -> Double {
        min(viewportWidth / game.logicalResolution.x, viewportHeight / game.logicalResolution.y)
    }

}

struct CanvasDisplaySize: Equatable {
    let displayWidth: Double
    let displayHeight: Double
    let backingWidth: Double
    let backingHeight: Double
}

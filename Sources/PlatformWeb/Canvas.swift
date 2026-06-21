import JavaScriptKit
import Swift

extension Runtime {
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

    func syncCanvasWithGameResolution() {
        guard let canvas, let gl else { return }

        if canvas.width.number != game.size.x {
            canvas.width = .number(game.size.x)
        }

        if canvas.height.number != game.size.y {
            canvas.height = .number(game.size.y)
        }

        fitCanvasElementToViewport(canvas)
        _ = gl.viewport!(0, 0, game.size.x, game.size.y)
    }

    func fitCanvasElementToViewport(_ canvas: JSObject) {
        let viewportWidth = JSObject.global.innerWidth.number ?? game.size.x
        let viewportHeight = JSObject.global.innerHeight.number ?? game.size.y
        let scale = displayScale(viewportWidth: viewportWidth, viewportHeight: viewportHeight)
        let displayWidth = game.size.x * scale
        let displayHeight = game.size.y * scale

        canvas.style.imageRendering = .string(imageRendering)
        canvas.style.width = .string("\(displayWidth)px")
        canvas.style.height = .string("\(displayHeight)px")
    }

    private func displayScale(viewportWidth: Double, viewportHeight: Double) -> Double {
        let fitScale = min(viewportWidth / game.size.x, viewportHeight / game.size.y)

        switch game.interpolationMode {
        case .linear:
            return fitScale
        case .nearest:
            guard fitScale >= 1 else { return fitScale }

            return max(1, fitScale.rounded(.down))
        }
    }

    private var imageRendering: String {
        switch game.interpolationMode {
        case .linear:
            return "auto"
        case .nearest:
            return "pixelated"
        }
    }
}

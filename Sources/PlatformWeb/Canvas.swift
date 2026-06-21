import JavaScriptKit
import Swift

extension BrowserRuntime {
    func configureCanvas() {
        let document = JSObject.global.document
        guard let canvas = document.getElementById("game").object else {
            fatalError("Missing canvas element with id 'game'")
        }

        self.canvas = canvas
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

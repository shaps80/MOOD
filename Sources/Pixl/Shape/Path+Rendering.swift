import Swift

extension Path {
    func forEachPrimitive(_ body: (RenderPrimitive) -> Void) {
        if let primitive = singlePrimitive() {
            body(.shape(primitive))
        }
    }

    private func singlePrimitive() -> ShapePrimitive? {
        if commands.count == 1 {
            switch commands[0] {
            case .addRect(let rect):
                return primitive(kind: .rect, bounds: rect, radius: 0)

            case .addRoundedRect(
                in: let rect,
                cornerRadius: let radius,
                style: let style
            ):
                return primitive(
                    kind: .roundedRect,
                    bounds: rect,
                    radius: min(radius, min(rect.size.x, rect.size.y) / 2),
                    cornerStyle: style
                )

            case .addEllipse(in: let rect):
                return primitive(kind: .ellipse, bounds: rect, radius: 0)

            default:
                return nil
            }
        }

        if commands.count == 2,
           case .move(to: let start) = commands[0],
           case .addLine(to: let end) = commands[1] {
            return linePrimitive(start: start, end: end)
        }

        return nil
    }

    private func primitive(
        kind: ShapePrimitiveKind,
        bounds: Rect,
        radius: Double,
        cornerStyle: RoundedCornerStyle = .continuous
    ) -> ShapePrimitive? {
        guard bounds.size.x > 0, bounds.size.y > 0 else {
            return nil
        }

        let fillColor = resolvedFillColor
        let stroke = resolvedStroke

        guard fillColor.alpha > 0 || stroke.color.alpha > 0 else {
            return nil
        }

        return ShapePrimitive(
            kind: kind,
            bounds: bounds,
            radius: radius,
            cornerStyle: cornerStyle,
            lineStart: .zero,
            lineEnd: .zero,
            fillColor: fillColor,
            strokeColor: stroke.color,
            strokeWidth: stroke.width,
            lineCap: stroke.lineCap,
            fillAntialiased: fill?.style.antialiased ?? true,
            strokeAntialiased: stroke.antialiased,
            blendMode: blendMode,
            layer: layer
        )
    }

    private func linePrimitive(start: Vec2, end: Vec2) -> ShapePrimitive? {
        let stroke = resolvedStroke

        guard stroke.color.alpha > 0, stroke.width > 0 else {
            return nil
        }

        let halfWidth = stroke.width / 2
        let extensionLength = stroke.lineCap == .square ? halfWidth : 0
        let minX = min(start.x, end.x) - halfWidth - extensionLength
        let minY = min(start.y, end.y) - halfWidth - extensionLength
        let maxX = max(start.x, end.x) + halfWidth + extensionLength
        let maxY = max(start.y, end.y) + halfWidth + extensionLength
        let bounds = Rect(
            x: minX,
            y: minY,
            width: max(maxX - minX, 1),
            height: max(maxY - minY, 1)
        )

        return ShapePrimitive(
            kind: .line,
            bounds: bounds,
            radius: 0,
            cornerStyle: .circular,
            lineStart: Vec2(
                x: start.x - bounds.origin.x,
                y: start.y - bounds.origin.y
            ),
            lineEnd: Vec2(
                x: end.x - bounds.origin.x,
                y: end.y - bounds.origin.y
            ),
            fillColor: .clear,
            strokeColor: stroke.color,
            strokeWidth: stroke.width,
            lineCap: stroke.lineCap,
            fillAntialiased: true,
            strokeAntialiased: stroke.antialiased,
            blendMode: blendMode,
            layer: layer
        )
    }

    private var resolvedFillColor: Color {
        guard let fill else { return .clear }
        return resolvedColor(fill.color)
    }

    private var resolvedStroke: (
        color: Color,
        width: Double,
        lineCap: LineCap,
        antialiased: Bool
    ) {
        guard let stroke, stroke.style.lineWidth > 0 else {
            return (.clear, 0, .butt, true)
        }

        return (
            resolvedColor(stroke.color),
            stroke.style.lineWidth,
            stroke.style.lineCap,
            stroke.style.antialiased
        )
    }

    private func resolvedColor(_ color: Color) -> Color {
        Color(
            red: color.red * tint.red,
            green: color.green * tint.green,
            blue: color.blue * tint.blue,
            alpha: color.alpha * tint.alpha * opacity
        )
    }
}

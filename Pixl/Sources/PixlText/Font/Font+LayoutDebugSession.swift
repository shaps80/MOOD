extension Font {
    package final class LayoutDebugSession {
        var shaping = ShapingWorkspace(minimumGlyphCapacity: 0, minimumRunCapacity: 0)
        var lineBreaking = LineBreakWorkspace()
        var lineLayout = LineLayoutWorkspace()
        var substitutionPlans: [OpenTypeShapingPlan] = []
        var positioningPlans: [OpenTypePositioningPlan] = []

        package init() {}

        package func layout(
            _ text: String,
            font: LayoutDebugInfo.FontInput,
            overrides: [LayoutDebugInfo.Input] = [],
            constraints: LayoutConstraints,
            lineHeight: LayoutDebugInfo.LineHeight,
            paragraphStyles: [ParagraphStyle]
        ) throws -> LayoutDebugInfo {
            shaping.removeAll()
            lineBreaking.removeAll()
            lineLayout.removeAll()
            substitutionPlans.removeAll(keepingCapacity: true)
            positioningPlans.removeAll(keepingCapacity: true)
            return try Registry.shared.layoutDebugInfo(
                in: text,
                font: font,
                overrides: overrides,
                constraints: constraints,
                lineHeight: lineHeight,
                paragraphStyles: paragraphStyles,
                session: self
            )
        }
    }
}

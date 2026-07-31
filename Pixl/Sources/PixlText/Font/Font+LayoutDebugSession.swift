extension Font {
    package final class LayoutDebugSession {
        private struct PlanSelectionKey: Hashable {
            let face: SFNT.Face
            let script: UInt32
            let language: UInt32?
        }

        var shaping = ShapingWorkspace(minimumGlyphCapacity: 0, minimumRunCapacity: 0)
        var lineBreaking = LineBreakWorkspace()
        var lineLayout = LineLayoutWorkspace()
        var substitutionPlans: [OpenTypeShapingPlan] = []
        var positioningPlans: [OpenTypePositioningPlan] = []
        private var substitutionTemplates: [SFNT.FaceID: OpenTypeShapingPlan] = [:]
        private var positioningTemplates: [SFNT.FaceID: OpenTypePositioningPlan] = [:]
        private var substitutionPlanIndices: [PlanSelectionKey: Int] = [:]
        private var positioningPlanIndices: [PlanSelectionKey: Int] = [:]

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
            substitutionPlanIndices.removeAll(keepingCapacity: true)
            positioningPlanIndices.removeAll(keepingCapacity: true)
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

        func substitutionPlanIndex(
            for face: SFNT.Face,
            script: UnicodeScript,
            language: UInt32?,
            source: SFNT.GlyphSubstitution
        ) -> Int {
            let key = PlanSelectionKey(face: face, script: script.tag, language: language)
            if let index = substitutionPlanIndices[key] { return index }
            var plan: OpenTypeShapingPlan
            if let template = substitutionTemplates[face.id] {
                plan = template
            } else {
                plan = source.shapingPlan()
                substitutionTemplates[face.id] = plan
            }
            plan.executions = source.activeLookups(
                script: script.tag,
                language: language,
                coordinates: face.normalizedCoordinates
            ).map {
                .init(lookupIndex: $0.lookup.index, feature: $0.feature)
            }
            let index = substitutionPlans.count
            substitutionPlans.append(plan)
            substitutionPlanIndices[key] = index
            return index
        }

        func positioningPlanIndex(
            for face: SFNT.Face,
            script: UnicodeScript,
            language: UInt32?,
            source: SFNT.GlyphPositioning,
            variationStore: SFNT.ItemVariationStore?
        ) -> Int {
            let key = PlanSelectionKey(face: face, script: script.tag, language: language)
            if let index = positioningPlanIndices[key] { return index }
            var plan: OpenTypePositioningPlan
            if let template = positioningTemplates[face.id] {
                plan = template
            } else {
                plan = source.positioningPlan(variationStore: variationStore)
                positioningTemplates[face.id] = plan
            }
            plan.executions = source.activeLookups(
                script: script.tag,
                language: language,
                coordinates: face.normalizedCoordinates
            ).map {
                .init(lookupIndex: $0.lookup.index, feature: $0.feature)
            }
            plan.coordinates = face.normalizedCoordinates
            let index = positioningPlans.count
            positioningPlans.append(plan)
            positioningPlanIndices[key] = index
            return index
        }
    }
}

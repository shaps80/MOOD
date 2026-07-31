extension Font {
    package static func variationAxes(
        fontBytes: [UInt8],
        fontID: String
    ) throws -> [Axis] {
        try Registry.shared.variationAxes(fontBytes: fontBytes, fontID: fontID)
    }

    package static func namedVariationInstances(
        fontBytes: [UInt8],
        fontID: String
    ) throws -> [NamedInstance] {
        try Registry.shared.namedVariationInstances(fontBytes: fontBytes, fontID: fontID)
    }
}

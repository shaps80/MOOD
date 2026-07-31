extension SFNT {
    struct VariationAxis: Hashable, Sendable {
        let tag: UInt32
        let minimum: Float
        let defaultValue: Float
        let maximum: Float
        let flags: UInt16
        let nameID: UInt16
    }

    struct NamedVariationInstance: Hashable, Sendable {
        let nameID: UInt16
        let postScriptNameID: UInt16?
        let coordinates: [Float]
    }
}

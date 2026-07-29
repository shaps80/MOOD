struct TextRun {
    let sourceRange: Range<Int>
    let face: SFNT.Face
    let size: Float
    let direction: TextDirection
    let script: UnicodeScript
    let language: UInt32?
    let substitutionPlanIndex: Int?
    let positioningPlanIndex: Int?
}

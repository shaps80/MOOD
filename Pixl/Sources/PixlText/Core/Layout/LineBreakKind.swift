enum LineBreakKind: UInt8, Hashable, Sendable {
    case allowed
    case softHyphen
    case automaticHyphen
    case mandatory
}

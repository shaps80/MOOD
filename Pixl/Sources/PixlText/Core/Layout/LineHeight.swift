enum LineHeight: Hashable, Sendable {
    case natural
    case multiple(Float)
    case atLeast(Float)
    case exactly(Float)

    var isValid: Bool {
        switch self {
        case .natural:
            true
        case .multiple(let value):
            value > 0 && value.isFinite
        case .atLeast(let value), .exactly(let value):
            value >= 0 && value.isFinite
        }
    }

    func resolve(natural: Float) -> Float {
        switch self {
        case .natural:
            natural
        case .multiple(let value):
            natural * value
        case .atLeast(let value):
            max(natural, value)
        case .exactly(let value):
            value
        }
    }
}

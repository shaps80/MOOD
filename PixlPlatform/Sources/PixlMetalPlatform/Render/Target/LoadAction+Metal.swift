import Metal
import PixlPlatform

extension LoadAction {
    var metalLoadAction: MTLLoadAction {
        switch self {
        case .load:
            return .load
        case .clear:
            return .clear
        case .discard:
            return .dontCare
        }
    }
}

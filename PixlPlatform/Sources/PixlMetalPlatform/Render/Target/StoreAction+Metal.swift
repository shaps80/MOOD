import Metal
import PixlPlatform

extension StoreAction {
    var metalStoreAction: MTLStoreAction {
        switch self {
        case .store:
            return .store
        case .discard:
            return .dontCare
        }
    }
}

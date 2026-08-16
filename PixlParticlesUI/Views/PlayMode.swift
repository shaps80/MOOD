import Foundation

enum PlayMode: String, Codable, CaseIterable, Hashable {
    case play
    case loop

    var title: LocalizedStringResource {
        switch self {
        case .play: "Play"
        case .loop: "Loop"
        }
    }
}

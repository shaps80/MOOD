import SwiftUI

struct PanelCustomization: Equatable, Sendable, Codable {
    var visibility: Set<String> = []
    public init() { }

    public subscript(visibility id: String) -> Visibility {
        get { visibility.contains(id) ? .visible : .hidden }
        set {
            if newValue == .hidden {
                visibility.remove(id)
            } else {
                visibility.insert(id)
            }
        }
    }
}

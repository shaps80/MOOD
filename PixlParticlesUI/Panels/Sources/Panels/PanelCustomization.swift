import SwiftUI

public struct PanelCustomization: Equatable, Sendable, Codable {
    var visibility: Set<String> = []
    public init() { }

    public subscript(visibility id: String) -> Visibility {
        get { visibility.contains(id) ? .hidden : .visible }
        set {
            if newValue == .hidden {
                visibility.insert(id)
            } else {
                visibility.remove(id)
            }
        }
    }
}

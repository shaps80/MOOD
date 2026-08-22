import SwiftUI

public struct PanelCustomization<ID>: Equatable where ID: Hashable {
    private(set) var visibility: Set<ID> = []
    private(set) var zOrder: [ID] = []

    internal var placement: [ID: UnitPoint] = [:]

    public init() { }

    public subscript(visibility id: ID) -> Visibility {
        get { visibility.contains(id) ? .hidden : .visible }
        set {
            if newValue == .hidden {
                visibility.insert(id)
            } else {
                visibility.remove(id)
            }
        }
    }

    public subscript(zOrder id: ID) -> Int {
        zOrder.firstIndex(of: id) ?? zOrder.count
    }

    public mutating func bringToFront(_ id: ID) {
        zOrder.removeAll { $0 == id }
        zOrder.append(id)
    }
}

extension PanelCustomization: Sendable where ID: Sendable { }
extension PanelCustomization: Codable where ID: Codable { }

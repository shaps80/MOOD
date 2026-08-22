import SwiftUI

internal extension SubviewsCollection {
    func ordered<ID: Hashable>(by customization: PanelCustomization<ID>) -> [Element] {
        let declaredIDs = compactMap {
            $0.containerValues.tag(for: ID.self)
        }
        let declaredIDSet = Set(declaredIDs)
        let storedIDs = customization.zOrder.filter(declaredIDSet.contains)
        let storedIDSet = Set(storedIDs)
        let resolvedOrder = declaredIDs.filter { !storedIDSet.contains($0) } + storedIDs

        return sorted { lhs, rhs in
            guard
                let lhsID = lhs.containerValues.tag(for: ID.self),
                let rhsID = rhs.containerValues.tag(for: ID.self),
                let lhsIndex = resolvedOrder.firstIndex(of: lhsID),
                let rhsIndex = resolvedOrder.firstIndex(of: rhsID)
                    else {
                return false
            }

            return lhsIndex < rhsIndex
        }
    }
}

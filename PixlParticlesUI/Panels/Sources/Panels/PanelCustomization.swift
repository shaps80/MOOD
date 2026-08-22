import Foundation
import SwiftUI

public struct PanelCustomization<ID>: Equatable where ID: Hashable & Codable & Sendable {
    private struct Storage: Equatable, Codable, Sendable {
        var visibility: Set<ID> = []
        var zOrder: [ID] = []
        var placement: [ID: UnitPoint] = [:]
    }

    private var storage = Storage()

    private(set) var visibility: Set<ID> {
        get { storage.visibility }
        set { storage.visibility = newValue }
    }

    private(set) var zOrder: [ID] {
        get { storage.zOrder }
        set { storage.zOrder = newValue }
    }

    internal var placement: [ID: UnitPoint] {
        get { storage.placement }
        set { storage.placement = newValue }
    }

    public init() { }

    private init(storage: Storage) {
        self.storage = storage
    }

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
        zOrder.firstIndex(of: id) ?? 0
    }

    public mutating func bringToFront(_ id: ID) {
        zOrder.removeAll { $0 == id }
        zOrder.append(id)
    }
}

extension PanelCustomization: Sendable where ID: Sendable { }

extension PanelCustomization: Codable {
    public init(from decoder: Decoder) throws {
        storage = try Storage(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try storage.encode(to: encoder)
    }
}

extension PanelCustomization: RawRepresentable {
    public init?(rawValue: String) {
        guard
            let data = Data(base64Encoded: rawValue),
            let storage = try? JSONDecoder().decode(Storage.self, from: data)
        else {
            return nil
        }

        self.init(storage: storage)
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(storage) else {
            assertionFailure("Panel customization could not be encoded")
            return ""
        }

        return data.base64EncodedString()
    }
}

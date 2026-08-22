import Foundation
import SwiftUI

public struct PanelCustomization<ID>: Equatable where ID: Hashable & Codable & Sendable {
    private var storage = Storage()

    private var visibility: [ID: VisibilityOverride] {
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
        get {
            switch visibility[id] {
            case .visible: .visible
            case .hidden: .hidden
            case nil: .automatic
            }
        }
        set {
            switch newValue {
            case .visible:
                visibility[id] = .visible
            case .hidden:
                visibility[id] = .hidden
            case .automatic:
                visibility[id] = nil
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

    public mutating func resetVisibility() {
        visibility.removeAll()
    }

    public mutating func resetPlacements() {
        placement.removeAll()
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

private extension PanelCustomization {
    enum VisibilityOverride: String, Equatable, Codable, Sendable {
        case visible
        case hidden
    }

    struct Storage: Equatable, Codable, Sendable {
        var visibility: [ID: VisibilityOverride] = [:]
        var zOrder: [ID] = []
        var placement: [ID: UnitPoint] = [:]

        private enum CodingKeys: String, CodingKey {
            case visibility
            case zOrder
            case placement
        }

        init() { }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let visibility = try? container.decode([ID: VisibilityOverride].self, forKey: .visibility) {
                self.visibility = visibility
            } else {
                let hiddenIDs = try container.decodeIfPresent(Set<ID>.self, forKey: .visibility) ?? []
                visibility = Dictionary(uniqueKeysWithValues: hiddenIDs.map { ($0, .hidden) })
            }

            zOrder = try container.decodeIfPresent([ID].self, forKey: .zOrder) ?? []
            placement = try container.decodeIfPresent([ID: UnitPoint].self, forKey: .placement) ?? [:]
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(visibility, forKey: .visibility)
            try container.encode(zOrder, forKey: .zOrder)
            try container.encode(placement, forKey: .placement)
        }
    }
}

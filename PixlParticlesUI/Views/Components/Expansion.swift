import SwiftUI

public struct Expansions<Value: Hashable>: Equatable, Sendable {
    @Observable
    fileprivate final class Wrapper: Equatable {
        var expansions: Set<Value>

        init(expansions: Set<Value> = []) {
            self.expansions = expansions
        }

        static func == (lhs: Wrapper, rhs: Wrapper) -> Bool {
            lhs.expansions == rhs.expansions
        }
    }

    @Bindable
    private var wrapper: Wrapper = .init()

    public init() {}

    public static func == (lhs: Expansions, rhs: Expansions) -> Bool {
        lhs.wrapper == rhs.wrapper
    }
}

extension Expansions {
    public mutating func callAsFunction(_ expansion: Value) -> Bool {
        self[expansion]
    }

    public subscript(_ expansion: Value) -> Bool {
        get {
            !contains(expansion)
        } set {
            if newValue {
                expand(expansion)
            } else {
                collapse(expansion)
            }
        }
    }

    public mutating func toggle(_ expansions: Value...) {
        toggle(contentsOf: expansions)
    }

    public mutating func toggle<S: Collection>(contentsOf expansions: S) where S.Element == Value {
        expansions.forEach { self[$0].toggle() }
    }

    public mutating func collapse(_ expansions: Value...) {
        collapse(contentsOf: expansions)
    }

    public mutating func collapse<S: Collection>(contentsOf expansions: S) where S.Element == Value {
        expansions.forEach { insert($0) }
    }

    public mutating func expand(_ expansions: Value...) {
        expand(contentsOf: expansions)
    }

    public mutating func expand<S: Collection>(contentsOf expansions: S) where S.Element == Value {
        expansions.forEach { remove($0) }
    }
}

extension Expansions: SetAlgebra {
    public typealias Element = Value
    public typealias ArrayLiteralElement = Value
    public typealias Sequence = Set<Value>

    public func union(_ other: Expansions<Value>) -> Expansions<Value> {
        .init(wrapper.expansions.union(other.wrapper.expansions))
    }

    public func intersection(_ other: Expansions<Value>) -> Expansions<Value> {
        .init(wrapper.expansions.intersection(other.wrapper.expansions))
    }

    public func symmetricDifference(_ other: Expansions<Value>) -> Expansions<Value> {
        .init(wrapper.expansions.symmetricDifference(other.wrapper.expansions))
    }

    public mutating func formUnion(_ other: Expansions<Value>) {
        wrapper.expansions.formUnion(other.wrapper.expansions)
    }

    public mutating func formIntersection(_ other: Expansions<Value>) {
        wrapper.expansions.formIntersection(other.wrapper.expansions)
    }

    public mutating func formSymmetricDifference(_ other: Expansions<Value>) {
        wrapper.expansions.formSymmetricDifference(other.wrapper.expansions)
    }

    public func contains(_ member: Value) -> Bool {
        wrapper.expansions.contains(member)
    }

    @discardableResult
    public mutating func insert(_ newMember: Value) -> (inserted: Bool, memberAfterInsert: Value) {
        wrapper.expansions.insert(newMember)
    }

    @discardableResult
    public mutating func remove(_ member: Value) -> Value? {
        wrapper.expansions.remove(member)
    }

    @discardableResult
    public mutating func update(with newMember: Value) -> Value? {
        wrapper.expansions.update(with: newMember)
    }
}

extension Expansions: Sequence {
    public func makeIterator() -> Set<Value>.Iterator {
        wrapper.expansions.makeIterator()
    }
}

extension Expansions.Wrapper: Codable where Value: Codable {
    private enum CodingKeys: String, CodingKey {
        case expansions
    }

    convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let expansions = try container.decode(Set<Value>.self, forKey: .expansions)
        self.init(expansions: expansions)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(expansions, forKey: .expansions)
    }
}

extension Expansions: Codable where Value: Codable {
    public init(from decoder: any Decoder) throws {
        wrapper = try .init(from: decoder)
    }

    public func encode(to encoder: any Encoder) throws {
        try wrapper.encode(to: encoder)
    }
}

extension Expansions: RawRepresentable where Value: Codable {
    public var rawValue: String {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(wrapper)
            return String(decoding: data, as: UTF8.self)
        } catch {
            print(error)
            return ""
        }
    }

    public init(rawValue: String) {
        do {
            let data = Data(rawValue.utf8)
            let decoder = JSONDecoder()
            wrapper = try decoder.decode(Wrapper.self, from: data)
        } catch {
            print(error)
        }
    }
}

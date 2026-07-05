import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ComponentMacro {}

extension ComponentMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let name = declaration.nominalName else { return [] }

        let placeholders = declaration.storedProperties
            .compactMap(\.label)
            .map { "_\($0) = _PixlNoType()" }
            .joined(separator: "\n")

        return [
            """
            let _$handle: ComponentHandle<\(raw: name)Schema, \(raw: name)Group>
            """,
            """
            let _$row: Int
            """,
            """
            let _$frameID: UInt64
            """,
            """
            unowned let _$storage: Store
            """,
            """
            unowned let _$componentStore: ComponentStore<\(raw: name)Schema, \(raw: name)Group>
            """,
            """
            public var _pixlComponentHandle: ComponentHandle<\(raw: name)Schema, \(raw: name)Group> {
                _$handle
            }
            """,
            """
            public init(
                handle: ComponentHandle<\(raw: name)Schema, \(raw: name)Group>,
                row: Int,
                frameID: UInt64,
                storage: Store
            ) {
                \(raw: placeholders)
                self._$handle = handle
                self._$row = row
                self._$frameID = frameID
                self._$storage = storage
                self._$componentStore = storage._pixlStore(\(raw: name)Schema.self, \(raw: name)Group.self)
            }
            """,
            """
            private struct _PixlNoType {}
            """
        ]
    }
}

extension ComponentMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let name = declaration.nominalName,
              let property = member.as(VariableDeclSyntax.self),
              property.isStoredProperty,
              let label = property.label
        else {
            return []
        }

        return [
            """
            @_PixlStored(schema: "\(raw: name)Schema", group: "\(raw: name)Group", column: "\(raw: label)", owner: "component")
            """
        ]
    }
}

extension ComponentMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let group = declaration.as(StructDeclSyntax.self) else { return [] }
        let name = group.name.text
        let properties = group.storedProperties

        let columns = properties.map { property -> String in
            "public var \(property.label!): [\(property.typeName!)]"
        }.joined(separator: "\n        ")

        let initColumns = properties.map { "self.\($0.label!) = []" }.joined(separator: "\n            ")
        let initialize = properties.map { property -> String in
            let defaultValue = property.initializerExpression ?? "\(property.typeName!)()"
            return "\(property.label!) = Array(repeating: \(defaultValue), count: capacity)"
        }.joined(separator: "\n            ")
        let grow = properties.map { property -> String in
            let defaultValue = property.initializerExpression ?? "\(property.typeName!)()"
            return "\(property.label!).append(contentsOf: repeatElement(\(defaultValue), count: newCapacity - oldCapacity))"
        }.joined(separator: "\n            ")
        let reset = properties.map { property -> String in
            let defaultValue = property.initializerExpression ?? "\(property.typeName!)()"
            return "\(property.label!)[row] = \(defaultValue)"
        }.joined(separator: "\n            ")
        let swapRows = properties.map { "\($0.label!).swapAt(lhs, rhs)" }.joined(separator: "\n            ")
        let moveRows = properties.map { "\($0.label!)[destination] = \($0.label!)[source]" }.joined(separator: "\n            ")

        return [
            """
            public enum \(raw: name)Schema: ComponentSchema {
                public static let name: StaticString = "\(raw: name)"

                public struct Columns: ComponentColumns {
                    \(raw: columns)

                    public init() {
                        \(raw: initColumns)
                    }

                    public mutating func initializeStorage(capacity: Int) {
                        \(raw: initialize)
                    }

                    public mutating func growStorage(from oldCapacity: Int, to newCapacity: Int) {
                        \(raw: grow)
                    }

                    public mutating func resetRowToDefault(_ row: Int) {
                        \(raw: reset)
                    }

                    public mutating func swapRows(_ lhs: Int, _ rhs: Int) {
                        \(raw: swapRows)
                    }

                    public mutating func moveRow(from source: Int, to destination: Int) {
                        \(raw: moveRows)
                    }
                }
            }
            """,
            """
            public enum \(raw: name)Group: StorageGroup {
                public static let name: StaticString = "\(raw: name)"
                public static let orderPolicy: OrderPolicy = .stable
                public static let initialCapacity = 150_000
            }
            """
        ]
    }
}

extension ComponentMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let name = declaration.nominalName else { return [] }

        let frameComponent: DeclSyntax = """
        extension \(type.trimmed): FrameComponent, _PixlComponentType {
            public typealias _PixlSchema = \(raw: name)Schema
            public typealias _PixlGroup = \(raw: name)Group
        }
        """
        return frameComponent.as(ExtensionDeclSyntax.self).map { [$0] } ?? []
    }
}

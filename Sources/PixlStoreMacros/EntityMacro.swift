import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct EntityMacro {}

extension EntityMacro: MemberMacro {
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
            public let id: EntityID
            """,
            """
            private let _$row: Int
            """,
            """
            private let _$frameID: UInt64
            """,
            """
            private unowned let _$storage: Store
            """,
            """
            private unowned let _$entityStore: ComponentStore<\(raw: name)Schema, \(raw: name)Group>
            """,
            """
            public init(id: EntityID, row: Int, frameID: UInt64, storage: Store) {
                \(raw: placeholders)
                self.id = id
                self._$row = row
                self._$frameID = frameID
                self._$storage = storage
                self._$entityStore = storage._pixlStore(\(raw: name)Schema.self, \(raw: name)Group.self)
            }
            """,
            """
            private struct _PixlNoType {}
            """
        ]
    }
}

extension EntityMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let name = declaration.nominalName,
              let property = member.as(VariableDeclSyntax.self),
              property.isStoredProperty,
              let label = property.label,
              property.typeName != nil
        else { return [] }

        let owner = property.initializerExpression == nil ? "entityComponent" : "entityValue"

        return [
            """
            @_PixlStored(schema: "\(raw: name)Schema", group: "\(raw: name)Group", column: "\(raw: label)", owner: "\(raw: owner)")
            """
        ]
    }
}

extension EntityMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let group = declaration.as(StructDeclSyntax.self) else { return [] }
        let name = group.name.text
        let properties = group.storedProperties

        let columns = (["public var entityID: [EntityID]"] + properties.map { property -> String in
            "public var \(property.label!): EntityPropertyColumn<\(property.typeName!)>"
        }).joined(separator: "\n        ")

        let initColumns = (["self.entityID = []"] + properties.map { "self.\($0.label!) = EntityPropertyColumn()" }).joined(separator: "\n            ")
        let initialize = (["entityID = Array(repeating: EntityID(index: -1, generation: -1), count: capacity)"] + properties.map { property -> String in
            let defaultValue = property.initializerExpression.map { "Optional.some(\($0))" } ?? "Optional.none"
            return "_pixlInitializeEntityColumn(&\(property.label!), capacity: capacity, defaultValue: \(defaultValue))"
        }).joined(separator: "\n            ")
        let grow = (["entityID.append(contentsOf: repeatElement(EntityID(index: -1, generation: -1), count: newCapacity - oldCapacity))"] + properties.map { property -> String in
            let defaultValue = property.initializerExpression.map { "Optional.some(\($0))" } ?? "Optional.none"
            return "_pixlGrowEntityColumn(&\(property.label!), from: oldCapacity, to: newCapacity, defaultValue: \(defaultValue))"
        }).joined(separator: "\n            ")
        let reset = (["entityID[row] = EntityID(index: -1, generation: -1)"] + properties.map { property -> String in
            let defaultValue = property.initializerExpression.map { "Optional.some(\($0))" } ?? "Optional.none"
            return "_pixlResetEntityColumnRow(&\(property.label!), row: row, defaultValue: \(defaultValue))"
        }).joined(separator: "\n            ")
        let swapRows = (["entityID.swapAt(lhs, rhs)"] + properties.map { "_pixlSwapEntityColumnRows(&\($0.label!), lhs, rhs)" }).joined(separator: "\n            ")
        let moveRows = (["entityID[destination] = entityID[source]"] + properties.map { "_pixlMoveEntityColumnRow(&\($0.label!), from: source, to: destination)" }).joined(separator: "\n            ")

        return [
            """
            public enum \(raw: name)Schema: EntitySchema {
                public static let name: StaticString = "\(raw: name)"

                public struct Columns: EntityColumns {
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

extension EntityMacro {
    private static func schemaMetadataLines(properties: [VariableDeclSyntax]) -> String {
        properties.compactMap { property -> String? in
            guard let label = property.label,
                  let type = property.typeName
            else { return nil }

            let hasDefaultValue = property.initializerExpression == nil ? "false" : "true"
            return "PixlPropertyMetadata(name: \"\(label)\", valueType: \(type).self, hasDefaultValue: \(hasDefaultValue))"
        }.joined(separator: ",\n            ")
    }

    private static func componentCreateLines(properties: [VariableDeclSyntax]) -> String {
        properties.compactMap { property -> String? in
            guard let label = property.label,
                  let type = property.typeName
            else { return nil }

            return "_pixlCreateEntityProperty(storage: storage, column: &entityStore.columns.\(label), row: row, as: \(type).self)"
        }.joined(separator: "\n        ")
    }

    private static func componentDestroyLines(properties: [VariableDeclSyntax]) -> String {
        properties.compactMap { property -> String? in
            guard let label = property.label,
                  let type = property.typeName
            else { return nil }

            return "_pixlDestroyEntityProperty(storage: storage, column: &entityStore.columns.\(label), row: row, as: \(type).self)"
        }.joined(separator: "\n        ")
    }
}

extension EntityMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let name = declaration.nominalName else { return [] }
        let metadata = schemaMetadataLines(properties: declaration.storedProperties)
        let create = componentCreateLines(properties: declaration.storedProperties)
        let destroy = componentDestroyLines(properties: declaration.storedProperties)

        let extensionSyntax: DeclSyntax = """
        extension \(type.trimmed): FrameEntity, _PixlEntityType, PixlStoreSchemaType {
            public typealias _PixlSchema = \(raw: name)Schema
            public typealias _PixlGroup = \(raw: name)Group

            public static var pixlSchemaMetadata: [PixlPropertyMetadata] {
                [
                    \(raw: metadata)
                ]
            }

            public static func _pixlCreateComponents(storage: Store, row: Int) {
                let entityStore = storage._pixlStore(_PixlSchema.self, _PixlGroup.self)
                \(raw: create)
            }

            public static func _pixlDestroyComponents(storage: Store, row: Int) {
                let entityStore = storage._pixlStore(_PixlSchema.self, _PixlGroup.self)
                \(raw: destroy)
            }
        }
        """
        return extensionSyntax.as(ExtensionDeclSyntax.self).map { [$0] } ?? []
    }
}

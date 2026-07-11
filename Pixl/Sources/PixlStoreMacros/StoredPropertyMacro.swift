import SwiftSyntax
import SwiftSyntaxMacros

public struct StoredPropertyMacro {}

extension StoredPropertyMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let property = declaration.as(VariableDeclSyntax.self),
              property.isStoredProperty,
              let label = property.label
        else {
            return []
        }

        return [
            """
            private var _\(raw: label): _PixlNoType
            """
        ]
    }
}

extension StoredPropertyMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let property = declaration.as(VariableDeclSyntax.self),
              property.isStoredProperty,
              let label = property.label,
              let type = property.typeName,
              let arguments = node.arguments?.as(LabeledExprListSyntax.self)
        else {
            return []
        }

        let column = stringArgument(named: "column", in: arguments) ?? label
        let owner = stringArgument(named: "owner", in: arguments) ?? "entity"
        let backingName = "_\(label)"

        let initializer: AccessorDeclSyntax = """
        @storageRestrictions(initializes: \(raw: backingName))
        init(initialValue) {
            \(raw: backingName) = _PixlNoType()
        }
        """

        if owner == "component" {
            return [
                initializer,
                componentGetter(column: column),
                componentSetter(column: column)
            ]
        }

        if owner == "entityValue" {
            return [
                initializer,
                entityValueGetter(column: column),
                entityValueSetter(column: column)
            ]
        }

        return [
            initializer,
            entityGetter(column: column, type: type),
            entitySetter(column: column)
        ]
    }

    private static func entityValueGetter(column: String) -> AccessorDeclSyntax {
        """
        get {
            _$entityStore.columns.\(raw: column).values[_$row]
        }
        """
    }

    private static func entityValueSetter(column: String) -> AccessorDeclSyntax {
        """
        nonmutating set {
            _$storage.assertWritableFrame(_$frameID)
            _$entityStore.columns.\(raw: column).values[_$row] = newValue
        }
        """
    }

    private static func entityGetter(column: String, type: String) -> AccessorDeclSyntax {
        """
        get {
            _pixlReadEntityProperty(storage: _$storage, column: _$entityStore.columns.\(raw: column), row: _$row, as: \(raw: type).self)
        }
        """
    }

    private static func entitySetter(column: String) -> AccessorDeclSyntax {
        """
        nonmutating set {
            _$storage.assertWritableFrame(_$frameID)
            _pixlWriteEntityProperty(storage: _$storage, column: &_$entityStore.columns.\(raw: column), row: _$row, value: newValue)
        }
        """
    }

    private static func componentGetter(column: String) -> AccessorDeclSyntax {
        """
        get {
            _$componentStore.columns.\(raw: column)[_$row]
        }
        """
    }

    private static func componentSetter(column: String) -> AccessorDeclSyntax {
        """
        nonmutating set {
            _$storage.assertWritableFrame(_$frameID)
            _$componentStore.columns.\(raw: column)[_$row] = newValue
        }
        """
    }
}

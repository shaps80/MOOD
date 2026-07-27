import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct EntryMacro: AccessorMacro, PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        let property = try EntryProperty(declaration)
        return [
            "get { self[\(raw: property.keyName).self] }",
            "set { self[\(raw: property.keyName).self] = newValue }"
        ]
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let property = try EntryProperty(declaration)
        let defaultValue: DeclSyntax
        if let type = property.type {
            defaultValue = """
            static var defaultValue: \(type) { \(property.initialValue) }
            """
        } else {
            defaultValue = """
            nonisolated(unsafe) static let defaultValue = \(property.initialValue)
            """
        }
        return [
            """
            private struct \(raw: property.keyName): EnvironmentKey {
                \(defaultValue)
            }
            """
        ]
    }
}

private struct EntryProperty {
    let name: String
    let type: TypeSyntax?
    let initialValue: ExprSyntax
    var keyName: String { "__Key_\(name)" }

    init(_ declaration: some DeclSyntaxProtocol) throws {
        guard let variable = declaration.as(VariableDeclSyntax.self),
              variable.bindingSpecifier.tokenKind == .keyword(.var),
              variable.bindings.count == 1,
              let binding = variable.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)
        else {
            throw MacroExpansionErrorMessage(
                "@Entry can only be attached to a single instance var"
            )
        }
        guard !variable.modifiers.contains(where: {
            $0.name.tokenKind == .keyword(.static)
                || $0.name.tokenKind == .keyword(.class)
        }) else {
            throw MacroExpansionErrorMessage("@Entry cannot be static")
        }
        guard binding.accessorBlock == nil else {
            throw MacroExpansionErrorMessage("@Entry cannot have accessors")
        }
        guard let initialValue = binding.initializer?.value else {
            throw MacroExpansionErrorMessage("@Entry requires a default value")
        }

        name = identifier.identifier.text
        type = binding.typeAnnotation?.type
        self.initialValue = initialValue
    }
}

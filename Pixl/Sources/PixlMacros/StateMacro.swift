import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct StateMacro: AccessorMacro, PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        let property = try StateProperty(declaration)
        return [
            """
            @storageRestrictions(initializes: \(raw: property.storageName))
            init(initialValue) {
                \(raw: property.storageName) = _StateStorage(
                    field: \(literal: property.name),
                    initialValue: initialValue
                )
            }
            """,
            """
            get { \(raw: property.storageName).wrappedValue }
            """,
            """
            nonmutating set { \(raw: property.storageName).wrappedValue = newValue }
            """
        ]
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let property = try StateProperty(declaration)
        let access = property.access
        let storage: DeclSyntax
        if let initialValue = property.initialValue {
            storage = """
            \(raw: access)var \(raw: property.storageName) = _StateStorage(
                field: \(literal: property.name),
                makeInitialValue: { \(initialValue) }
            )
            """
        } else if let type = property.type {
            storage = """
            \(raw: access)var \(raw: property.storageName): _StateStorage<\(type)>
            """
        } else {
            throw MacroExpansionErrorMessage(
                "@State requires an initial value or explicit type"
            )
        }

        let projection: DeclSyntax
        if let type = property.type {
            projection = """
            \(raw: access)var $\(raw: property.name): Binding<\(type)> {
                \(raw: property.storageName).projectedValue
            }
            """
        } else {
            projection = """
            @_StateProjection
            \(raw: access)var $\(raw: property.name) = _StateStorage(
                field: \(literal: property.name),
                initialValue: \(property.initialValue!)
            ).projectedValue
            """
        }
        return [storage, projection]
    }
}

public struct StateProjectionMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let variable = declaration.as(VariableDeclSyntax.self),
              variable.bindings.count == 1,
              let binding = variable.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)
        else {
            throw MacroExpansionErrorMessage("Invalid State projection")
        }
        let name = identifier.identifier.text
        guard name.first == "$" else {
            throw MacroExpansionErrorMessage("Invalid State projection")
        }
        return ["get { __\(raw: String(name.dropFirst())).projectedValue }"]
    }
}

private struct StateProperty {
    let name: String
    let type: TypeSyntax?
    let initialValue: ExprSyntax?
    let access: String
    var storageName: String { "__\(name)" }

    init(_ declaration: some DeclSyntaxProtocol) throws {
        guard let variable = declaration.as(VariableDeclSyntax.self),
              variable.bindingSpecifier.tokenKind == .keyword(.var),
              variable.bindings.count == 1,
              let binding = variable.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)
        else {
            throw MacroExpansionErrorMessage(
                "@State can only be attached to a single instance var"
            )
        }
        guard !variable.modifiers.contains(where: {
            $0.name.tokenKind == .keyword(.static)
                || $0.name.tokenKind == .keyword(.class)
        }) else {
            throw MacroExpansionErrorMessage("@State cannot be static")
        }

        name = identifier.identifier.text
        type = binding.typeAnnotation?.type
        initialValue = binding.initializer?.value
        access = variable.modifiers.compactMap { modifier -> String? in
            switch modifier.name.tokenKind {
            case .keyword(.private): "private "
            case .keyword(.fileprivate): "fileprivate "
            case .keyword(.package): "package "
            case .keyword(.internal): "internal "
            case .keyword(.public): "public "
            default: nil
            }
        }.first ?? ""
    }
}

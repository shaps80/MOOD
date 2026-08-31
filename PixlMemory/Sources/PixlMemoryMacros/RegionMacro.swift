import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct RegionMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let variable = declaration.as(VariableDeclSyntax.self),
              variable.bindingSpecifier.tokenKind == .keyword(.var),
              variable.bindings.count == 1,
              !variable.modifiers.contains(where: {
                  $0.name.tokenKind == .keyword(.static)
                      || $0.name.tokenKind == .keyword(.class)
              }),
              let binding = variable.bindings.first,
              binding.typeAnnotation != nil,
              binding.initializer == nil,
              binding.accessorBlock == nil
        else {
            throw MacroExpansionErrorMessage(
                "@Region requires a single uninitialized instance var with an explicit type"
            )
        }
        return [
            "get { fatalError(\"@Region declarations are namespace markers, not values\") }"
        ]
    }
}

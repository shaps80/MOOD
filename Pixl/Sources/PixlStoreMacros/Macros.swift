import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct PixlStorePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        EntityMacro.self,
        ComponentMacro.self,
        StoredPropertyMacro.self
    ]
}

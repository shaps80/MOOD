import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct PixlPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        InputProfileMacro.self,
        BindingMacro.self
    ]
}

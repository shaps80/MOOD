import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct PixlMemoryPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        LayoutMacro.self,
        RegionMacro.self
    ]
}

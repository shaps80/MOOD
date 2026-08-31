import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct LayoutMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let layout = try LayoutDeclaration(node: node, declaration: declaration)
        let access = declaration.modifiers.first(where: {
            [.keyword(.public), .keyword(.package)].contains($0.name.tokenKind)
        }).map { "\($0.name.text) " } ?? ""
        var members: [DeclSyntax] = [
            "\(raw: access)typealias Layout = PixlMemory.MemoryLayoutBuilder<Self>",
            "\(raw: access)static var memoryLayoutName: String { \(layout.name) }",
            "\(raw: access)static var preparationPolicy: PixlMemory.PreparationPolicy? { \(layout.policy) }",
            "\(raw: access)static var memoryRegionDeclarations: [PixlMemory.MemoryRegionDeclaration<Self>] { [\(raw: layout.regions.joined(separator: ", "))] }"
        ]
        if !layout.hasMake {
            members.append(
                "\(raw: access)static func make(_ layout: inout Layout) {}"
            )
        }
        return members
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        [
            try ExtensionDeclSyntax(
                "extension \(type.trimmed): PixlMemory.MemoryLayoutDefinition {}"
            )
        ]
    }

}

private struct LayoutDeclaration {
    let name: ExprSyntax
    let policy: ExprSyntax
    let hasMake: Bool
    let regions: [String]

    init(node: AttributeSyntax, declaration: some DeclGroupSyntax) throws {
        guard declaration.is(StructDeclSyntax.self) else {
            throw MacroExpansionErrorMessage("@Layout can only be attached to a struct")
        }
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              let first = arguments.first,
              first.label == nil
        else {
            throw MacroExpansionErrorMessage("@Layout requires a display name")
        }
        name = first.expression
        policy = arguments.first(where: {
            $0.label?.text == "policy"
        })?.expression ?? ExprSyntax("nil")
        hasMake = declaration.memberBlock.members.contains { member in
            guard let function = member.decl.as(FunctionDeclSyntax.self) else {
                return false
            }
            return function.name.text == "make"
        }
        regions = declaration.memberBlock.members.compactMap { member in
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                  let attribute = variable.attributes.compactMap({ $0.as(AttributeSyntax.self) }).first(where: { $0.attributeName.trimmedDescription == "Region" }),
                  let binding = variable.bindings.first,
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                  let type = binding.typeAnnotation?.type
            else { return nil }
            let arguments = attribute.arguments?.as(LabeledExprListSyntax.self)
            let first = arguments?.first
            let kind = first?.label == nil && first?.expression.trimmedDescription == ".densePool"
                ? ".densePool"
                : (type.trimmedDescription.hasSuffix("RawBytes") ? ".rawBuffer" : ".indexedBuffer")
            let policy = arguments?.first(where: { $0.label?.text == "policy" })?.expression.trimmedDescription ?? "nil"
            let name = identifier.identifier.text
            return "PixlMemory.MemoryRegionDeclaration(keyPath: \\Self.\(name), name: \"\(name)\", kind: \(kind), policy: \(policy), elementType: \(type.trimmedDescription).self)"
        }
    }
}

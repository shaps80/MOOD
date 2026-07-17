import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct InputProfileMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) else {
            throw MacroExpansionErrorMessage(
                "@InputProfile can only be attached to a struct"
            )
        }

        let inputs = try declaration.inputProperties
        guard !inputs.isEmpty else {
            throw MacroExpansionErrorMessage(
                "@InputProfile requires at least one @Binding property"
            )
        }

        let access = declaration.generatedAccess
        let initialization = inputs.map { input in
            let bindings = input.bindings.joined(separator: ",\n                ")
            return """
            self.\(input.name) = storage.input(
                bindings: [
                    \(bindings)
                ]
            )
            """
        }.joined(separator: "\n        ")

        return [
            """
            private let storage: Input.Profile
            """,
            """
            \(raw: access)init() {
                let storage = Input.Profile()
                self.storage = storage
                \(raw: initialization)
            }
            """,
            """
            \(raw: access)func bind(to map: Input.Map) {
                map.bind(storage)
            }
            """,
            """
            \(raw: access)func setBindings(
                _ bindings: [Input.Binding],
                for input: Input
            ) {
                storage.setBindings(bindings, for: input)
            }
            """
        ]
    }
}

private struct InputProperty {
    let name: String
    let bindings: [String]
}

private extension DeclGroupSyntax {
    var inputProperties: [InputProperty] {
        get throws {
            try memberBlock.members.compactMap { member in
                guard let property = member.decl.as(VariableDeclSyntax.self),
                      let attribute = property.bindingAttribute
                else {
                    return nil
                }

                guard property.bindingSpecifier.tokenKind == .keyword(.let),
                      property.bindings.count == 1,
                      let binding = property.bindings.first,
                      let identifier = binding.pattern.as(
                        IdentifierPatternSyntax.self
                      ),
                      binding.typeAnnotation?.type.trimmedDescription
                        .hasSuffix("Input") == true,
                      binding.initializer == nil
                else {
                    throw MacroExpansionErrorMessage(
                        "@Binding requires an uninitialized `let` property of type Input"
                    )
                }

                guard let arguments = attribute.arguments?.as(
                    LabeledExprListSyntax.self
                ), !arguments.isEmpty else {
                    throw MacroExpansionErrorMessage(
                        "@Binding requires at least one binding"
                    )
                }

                return InputProperty(
                    name: identifier.identifier.text,
                    bindings: arguments.map(
                        \.expression.trimmedDescription
                    )
                )
            }
        }
    }

    var generatedAccess: String {
        let modifiers: DeclModifierListSyntax
        if let declaration = self.as(StructDeclSyntax.self) {
            modifiers = declaration.modifiers
        } else {
            return ""
        }

        if modifiers.contains(where: { $0.name.tokenKind == .keyword(.public) }) {
            return "public "
        }
        if modifiers.contains(where: { $0.name.tokenKind == .keyword(.package) }) {
            return "package "
        }
        return ""
    }
}

private extension VariableDeclSyntax {
    var bindingAttribute: AttributeSyntax? {
        attributes.compactMap { element in
            element.as(AttributeSyntax.self)
        }.first { attribute in
            let name = attribute.attributeName.trimmedDescription
            return name == "Binding" || name.hasSuffix(".Binding")
        }
    }
}

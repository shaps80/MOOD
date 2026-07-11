import SwiftSyntax

extension VariableDeclSyntax {
    var isStoredProperty: Bool {
        if bindings.count != 1 {
            return false
        }

        switch bindings.first?.accessorBlock?.accessors {
        case .none:
            return true

        case .accessors(let accessors):
            for accessor in accessors {
                switch accessor.accessorSpecifier.tokenKind {
                case .keyword(.willSet), .keyword(.didSet):
                    break

                default:
                    return false
                }
            }

            return true

        case .getter:
            return false
        }
    }

    var label: String? {
        bindings.first?
            .pattern.as(IdentifierPatternSyntax.self)?
            .identifier.trimmedDescription
    }

    var typeName: String? {
        bindings.first?
            .typeAnnotation?
            .type
            .trimmedDescription
    }

    var initializerExpression: String? {
        bindings.first?
            .initializer?
            .value
            .trimmedDescription
    }
}

extension DeclGroupSyntax {
    var storedProperties: [VariableDeclSyntax] {
        memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .filter(\.isStoredProperty)
    }

    var nominalName: String? {
        if let structDecl = self.as(StructDeclSyntax.self) {
            return structDecl.name.text
        }

        if let classDecl = self.as(ClassDeclSyntax.self) {
            return classDecl.name.text
        }

        return nil
    }
}

func entityComponentNames(from node: AttributeSyntax) -> Set<String> {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
          let components = arguments.first(where: { $0.label?.text == "components" })
    else {
        return []
    }

    if let array = components.expression.as(ArrayExprSyntax.self) {
        return Set(array.elements.compactMap { element in
            element.expression.as(MemberAccessExprSyntax.self)?.base?.trimmedDescription
        })
    }

    return []
}

func stringArgument(named name: String, in arguments: LabeledExprListSyntax) -> String? {
    arguments.first { $0.label?.text == name }?
        .expression
        .as(StringLiteralExprSyntax.self)?
        .segments
        .first?
        .as(StringSegmentSyntax.self)?
        .content
        .text
}

import Swift

@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(`__`), prefixed(`$`))
public macro State() = #externalMacro(
    module: "PixlMacros",
    type: "StateMacro"
)

@_documentation(visibility: internal)
@attached(accessor)
public macro _StateProjection() = #externalMacro(
    module: "PixlMacros",
    type: "StateProjectionMacro"
)

import Swift

@attached(accessor)
@attached(peer, names: prefixed(__Key_))
public macro Entry() = #externalMacro(
    module: "PixlMacros",
    type: "EntryMacro"
)

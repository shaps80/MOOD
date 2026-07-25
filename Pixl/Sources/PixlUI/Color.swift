import Swift

@frozen public struct Color: View, Hashable, Sendable {
    public var red: Float
    public var green: Float
    public var blue: Float
    public var opacity: Float
    public init(red: Float, green: Float, blue: Float, opacity: Float = 1) { self.red = red; self.green = green; self.blue = blue; self.opacity = opacity }
    public static let clear = Color(red: 0, green: 0, blue: 0, opacity: 0)
    public static let black = Color(red: 0, green: 0, blue: 0)
    public static let white = Color(red: 1, green: 1, blue: 1)
    public static let red = Color(red: 1, green: 0, blue: 0)
    public static let green = Color(red: 0, green: 1, blue: 0)
    public static let blue = Color(red: 0, green: 0, blue: 1)
    public var body: Never { fatalError() }
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let payload = Int32(inputs.graph.colors.count); inputs.graph.colors.append(view.value)
        return .init(node: inputs.graph.appendNode(kind: .color, payload: payload, parent: inputs.parent))
    }
}

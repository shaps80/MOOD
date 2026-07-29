extension Font {
    package static func runDebugInfo(
        in text: String,
        runs: [RunDebugInfo.Input]
    ) throws -> RunDebugInfo {
        try Registry.shared.runDebugInfo(in: text, inputs: runs)
    }
}

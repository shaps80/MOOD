import PackagePlugin
import Foundation

@main
struct PixlShaderPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard target.name == "Game" else { return [] }

        let outputDirectory = context.pluginWorkDirectoryURL.appending(path: "Shaders")
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        let library = outputDirectory.appending(path: "PixlBuiltIn.metallib")

        return [
            .buildCommand(
                displayName: "Generating Pixl shaders",
                executable: try context.tool(named: "PixlShaderGenerator").url,
                arguments: ["--output", outputDirectory.path()],
                inputFiles: [],
                outputFiles: [library]
            )
        ]
    }
}

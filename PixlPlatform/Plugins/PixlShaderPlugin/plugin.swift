import PackagePlugin
import Foundation

@main
struct PixlShaderPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard target.name == "PixlGraphics" else { return [] }

        let outputDirectory = context.pluginWorkDirectoryURL.appending(path: "Shaders")
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        let library = outputDirectory.appending(path: "PixlGraphics.metallib")
        let registry = outputDirectory.appending(path: "ShaderCatalogue.swift")

        return [
            .buildCommand(
                displayName: "Generating Pixl shaders",
                executable: try context.tool(named: "PixlShaderGenerator").url,
                arguments: ["--output", outputDirectory.path()],
                inputFiles: [],
                outputFiles: [library, registry]
            )
        ]
    }
}

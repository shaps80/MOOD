import Foundation

@main
struct PixlShaderGenerator {
    static func main() throws {
        let arguments = CommandLine.arguments
        guard let outputIndex = arguments.firstIndex(of: "--output"),
              arguments.indices.contains(outputIndex + 1)
        else { throw ShaderGeneratorError.missingOutputDirectory }

        let outputDirectory = URL(fileURLWithPath: arguments[outputIndex + 1])
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let sourceURL = outputDirectory.appending(path: "PixlGraphics.metal")
        let airURL = outputDirectory.appending(path: "PixlGraphics.air")
        let libraryURL = outputDirectory.appending(path: "PixlGraphics.metallib")
        let registryURL = outputDirectory.appending(path: "ShaderCatalogue.swift")

        try source.write(to: sourceURL, atomically: true, encoding: .utf8)
        try registrySource.write(to: registryURL, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: airURL)
        }

        try run("metal", ["-c", sourceURL.path(), "-o", airURL.path()])
        try run("metallib", [airURL.path(), "-o", libraryURL.path()])
    }

    private static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexOutput {
        float4 position [[position]];
        float4 color;
    };

    struct VertexInput {
        float2 position [[attribute(0)]];
        float4 color [[attribute(1)]];
    };

    vertex VertexOutput pixlVertex(
        VertexInput input [[stage_in]],
        constant float3x3 &transform [[buffer(1)]]
    ) {
        float3 position = transform * float3(input.position, 1.0);
        return { float4(position.xy, 0.0, 1.0), input.color };
    }

    fragment float4 pixlFragment(VertexOutput input [[stage_in]]) {
        return input.color;
    }
    """

    private static let registrySource = """
    import Foundation
    import PixlPlatform

    public enum ShaderCatalogue {
        public static let `default`: Shader = {
        #if os(WASI)
            return Shader(wgslSource: wgslSource)
        #else
            guard let url = Bundle.module.url(
                forResource: "PixlGraphics",
                withExtension: "metallib"
            ) else {
                fatalError("Generated PixlGraphics shader library is missing")
            }

            guard let data = try? Data(contentsOf: url) else {
                fatalError("Generated PixlGraphics shader library could not be read")
            }

            return data.withUnsafeBytes {
                Shader(copyingMetal: $0, wgslSource: wgslSource)
            }
        #endif
        }()

        private static let wgslSource = \"\"\"
        struct VertexInput {
            @location(0) position: vec2f,
            @location(1) color: vec4f,
        }

        struct VertexOutput {
            @builtin(position) position: vec4f,
            @location(0) color: vec4f,
        }

        @group(0) @binding(0)
        var<uniform> transform: mat3x3f;

        @vertex
        fn pixlVertex(input: VertexInput) -> VertexOutput {
            var output: VertexOutput;
            let position = transform * vec3f(input.position, 1.0);
            output.position = vec4f(position.xy, 0.0, 1.0);
            output.color = input.color;
            return output;
        }

        @fragment
        fn pixlFragment(input: VertexOutput) -> @location(0) vec4f {
            return input.color;
        }
        \"\"\"
    }

    public enum Shaders {
        public static let vertex = ShaderFunction(
            shader: ShaderCatalogue.default,
            name: "pixlVertex"
        )

        public static let fragment = ShaderFunction(
            shader: ShaderCatalogue.default,
            name: "pixlFragment"
        )
    }
    """

    private static func run(_ tool: String, _ arguments: [String]) throws {
#if os(WASI)
        throw ShaderGeneratorError.toolFailed(tool)
#else
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = [tool] + arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ShaderGeneratorError.toolFailed(tool)
        }
#endif
    }
}

private enum ShaderGeneratorError: Error {
    case missingOutputDirectory
    case toolFailed(String)
}

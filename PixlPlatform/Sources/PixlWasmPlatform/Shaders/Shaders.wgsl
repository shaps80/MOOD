struct VertexInput {
    @location(0) position: vec2f,
    @location(1) color: vec4f,
    @location(2) textureCoordinate: vec2f,
}

struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) color: vec4f,
    @location(1) textureCoordinate: vec2f,
}

struct PrimitiveParameters {
    transform: mat3x3f,
    textureOrigin: vec2f,
    textureScale: vec2f,
}

@group(0) @binding(0)
var<uniform> parameters: PrimitiveParameters;

@group(0) @binding(1)
var texture: texture_2d<f32>;

@group(0) @binding(2)
var textureSampler: sampler;

@vertex
fn pixlVertex(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;
    let position = parameters.transform * vec3f(input.position, 1.0);
    output.position = vec4f(position.xy, 0.0, 1.0);
    output.color = input.color;
    output.textureCoordinate = parameters.textureOrigin
        + input.textureCoordinate * parameters.textureScale;
    return output;
}

@fragment
fn pixlFragment(input: VertexOutput) -> @location(0) vec4f {
    // Sampling preserves the texture's alpha representation. The selected
    // pipeline blend mode must expect straight or premultiplied fragment RGB.
    return textureSample(texture, textureSampler, input.textureCoordinate)
        * input.color;
}

struct SpriteVertexInput {
    @location(0) position: vec2f,
    @location(2) textureCoordinate: vec2f,
    @location(3) transformX: vec2f,
    @location(4) transformY: vec2f,
    @location(5) translation: vec2f,
    @location(6) textureOrigin: vec2f,
    @location(7) textureScale: vec2f,
    @location(8) tint: vec4f,
}

@vertex
fn pixlSpriteVertex(input: SpriteVertexInput) -> VertexOutput {
    var output: VertexOutput;
    let world = input.transformX * input.position.x
        + input.transformY * input.position.y
        + input.translation;
    let projected = parameters.transform * vec3f(world, 1.0);
    output.position = vec4f(projected.xy, 0.0, 1.0);
    output.color = input.tint;
    output.textureCoordinate = input.textureOrigin
        + input.textureCoordinate * input.textureScale;
    return output;
}

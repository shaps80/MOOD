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

@group(0) @binding(0)
var<uniform> transform: mat3x3f;

@group(0) @binding(1)
var texture: texture_2d<f32>;

@group(0) @binding(2)
var textureSampler: sampler;

@vertex
fn pixlVertex(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;
    let position = transform * vec3f(input.position, 1.0);
    output.position = vec4f(position.xy, 0.0, 1.0);
    output.color = input.color;
    output.textureCoordinate = input.textureCoordinate;
    return output;
}

@fragment
fn pixlFragment(input: VertexOutput) -> @location(0) vec4f {
    return textureSample(texture, textureSampler, input.textureCoordinate)
        * input.color;
}

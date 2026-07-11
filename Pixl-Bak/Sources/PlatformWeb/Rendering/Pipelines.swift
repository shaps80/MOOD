import Pixl
import JavaScriptKit

extension Renderer {
    func makePipelines() {
        guard let device else { return }
        let itemModule = device.createShaderModule!(object("label", "Pixl item shader", "code", itemShaderSource)).object!
        let presentModule = device.createShaderModule!(object("label", "Pixl present shader", "code", presentShaderSource)).object!

        pipelineStates = Dictionary(uniqueKeysWithValues: BlendMode.fixedFunctionModes.map { mode in
            (mode, makeItemPipeline(module: itemModule, blendMode: mode))
        })
        sampledPipeline = makeItemPipeline(module: itemModule, blendMode: .replace)

        let vertex = object("module", presentModule, "entryPoint", "presentVertex", "buffers", array(presentVertexLayout()))
        let fragment = object("module", presentModule, "entryPoint", "presentFragment", "targets", array(object("format", canvasFormat)))
        presentPipeline = device.createRenderPipeline!(object(
            "label", "Pixl present pipeline", "layout", "auto",
            "vertex", vertex, "fragment", fragment, "primitive", object("topology", "triangle-list")
        )).object
    }

    private func makeItemPipeline(module: JSObject, blendMode: BlendMode) -> JSObject {
        let vertex = object(
            "module", module, "entryPoint", "itemVertex",
            "buffers", array(quadVertexLayout(), itemInstanceLayout())
        )
        let target = object("format", "rgba8unorm")
        if let blend = blendDescriptor(for: blendMode) { target.blend = .object(blend) }
        let fragment = object("module", module, "entryPoint", "itemFragment", "targets", array(target))
        return device!.createRenderPipeline!(object(
            "label", "Pixl \(blendMode) pipeline", "layout", "auto",
            "vertex", vertex, "fragment", fragment, "primitive", object("topology", "triangle-list")
        )).object!
    }

    private func quadVertexLayout() -> JSObject {
        object(
            "arrayStride", 8, "stepMode", "vertex",
            "attributes", array(object("shaderLocation", 0, "offset", 0, "format", "float32x2"))
        )
    }

    private func presentVertexLayout() -> JSObject { quadVertexLayout() }

    private func itemInstanceLayout() -> JSObject {
        let attributes = JSObject.global.Array.object!.new()
        for location in 1...9 {
            _ = attributes.push!(object(
                "shaderLocation", location,
                "offset", (location - 1) * 16,
                "format", "float32x4"
            ))
        }
        return object("arrayStride", itemStrideBytes, "stepMode", "instance", "attributes", attributes)
    }

    private func blendDescriptor(for mode: BlendMode) -> JSObject? {
        func component(source: String, destination: String) -> JSObject {
            object("operation", "add", "srcFactor", source, "dstFactor", destination)
        }
        switch mode {
        case .replace: return nil
        case .normal:
            return object("color", component(source: "one", destination: "one-minus-src-alpha"), "alpha", component(source: "one", destination: "one-minus-src-alpha"))
        case .additive:
            return object("color", component(source: "one", destination: "one"), "alpha", component(source: "one", destination: "one"))
        case .multiply:
            return object("color", component(source: "dst", destination: "one-minus-src-alpha"), "alpha", component(source: "one", destination: "one-minus-src-alpha"))
        case .screen:
            return object("color", component(source: "one", destination: "one-minus-src"), "alpha", component(source: "one", destination: "one-minus-src-alpha"))
        default: return nil
        }
    }
}

private let presentShaderSource = """
struct PresentOut { @builtin(position) position: vec4f, @location(0) texCoord: vec2f }
@group(0) @binding(0) var sceneSampler: sampler;
@group(0) @binding(1) var sceneTexture: texture_2d<f32>;

@vertex fn presentVertex(@location(0) unitPosition: vec2f) -> PresentOut {
    var out: PresentOut;
    let clip = unitPosition * 2.0 - 1.0;
    out.position = vec4f(clip * vec2f(1.0, -1.0), 0.0, 1.0);
    out.texCoord = unitPosition;
    return out;
}

@fragment fn presentFragment(in: PresentOut) -> @location(0) vec4f {
    return textureSample(sceneTexture, sceneSampler, in.texCoord);
}
"""

private let itemShaderSource = """
struct Uniforms {
    resolution: vec2f,
    aaWidth: f32,
    padding0: f32,
    useTexture: f32,
    sampled: f32,
    blendMode: f32,
    padding1: f32,
}
struct ItemOut {
    @builtin(position) position: vec4f,
    @location(0) texCoord: vec2f,
    @location(1) color: vec4f,
    @location(2) localPosition: vec2f,
    @location(3) size: vec2f,
    @location(4) info: vec4f,
    @location(5) line: vec4f,
    @location(6) fillColor: vec4f,
    @location(7) strokeColor: vec4f,
    @location(8) flags: vec4f,
}
@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var itemSampler: sampler;
@group(0) @binding(2) var itemTexture: texture_2d<f32>;
@group(0) @binding(3) var sampledSceneTexture: texture_2d<f32>;

@vertex fn itemVertex(
    @location(0) unitPosition: vec2f,
    @location(1) transform: vec4f,
    @location(2) rotation: vec4f,
    @location(3) textureRect: vec4f,
    @location(4) color: vec4f,
    @location(5) info: vec4f,
    @location(6) line: vec4f,
    @location(7) fillColor: vec4f,
    @location(8) strokeColor: vec4f,
    @location(9) flags: vec4f
) -> ItemOut {
    let local = (unitPosition - vec2f(0.5)) * transform.zw;
    let rotated = vec2f(local.x * rotation.x - local.y * rotation.y, local.x * rotation.y + local.y * rotation.x);
    let clip = ((transform.xy + rotated) / uniforms.resolution) * 2.0 - 1.0;
    var out: ItemOut;
    out.position = vec4f(clip * vec2f(1.0, -1.0), 0.0, 1.0);
    out.texCoord = textureRect.xy + unitPosition * textureRect.zw;
    out.color = color; out.localPosition = unitPosition * transform.zw; out.size = transform.zw;
    out.info = info; out.line = line; out.fillColor = fillColor; out.strokeColor = strokeColor; out.flags = flags;
    return out;
}

fn roundedBoxDistance(p: vec2f, size: vec2f, radius: f32) -> f32 {
    let halfSize = size * 0.5;
    let q = abs(p - halfSize) - (halfSize - vec2f(radius));
    return length(max(q, vec2f(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}
fn continuousRoundedBoxDistance(p: vec2f, size: vec2f, radius: f32) -> f32 {
    let r = max(radius, 0.0); let halfSize = size * 0.5;
    let q = abs(p - halfSize) - (halfSize - vec2f(r)); let outside = max(q, vec2f(0.0));
    let outside2 = outside * outside; let outside4 = outside2 * outside2;
    let continuous = sqrt(sqrt(max(outside4.x + outside4.y, 0.0))) + min(max(q.x, q.y), 0.0) - r;
    return mix(roundedBoxDistance(p, size, r), continuous, 0.28 * step(0.0001, r));
}
fn ellipseDistance(p: vec2f, size: vec2f) -> f32 {
    let radius = max(size * 0.5, vec2f(0.0001));
    return (length((p - radius) / radius) - 1.0) * min(radius.x, radius.y);
}
fn segmentDistance(p: vec2f, a: vec2f, b: vec2f) -> f32 {
    let pa = p - a; let ba = b - a;
    let h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
    return length(pa - ba * h);
}
fn lineBoxDistance(p: vec2f, a: vec2f, b: vec2f, width: f32, cap: f32) -> f32 {
    let center = (a + b) * 0.5; let axis = b - a; let len = max(length(axis), 0.0001);
    let dir = axis / len; let normal = vec2f(-dir.y, dir.x);
    let halfLen = len * 0.5 + select(0.0, width * 0.5, cap > 0.5);
    let local = vec2f(dot(p - center, dir), dot(p - center, normal));
    let q = abs(local) - vec2f(halfLen, width * 0.5);
    return length(max(q, vec2f(0.0))) + min(max(q.x, q.y), 0.0);
}
fn coverage(distance: f32, antialiased: f32) -> f32 {
    return mix(step(distance, 0.0), clamp(0.5 - distance / max(uniforms.aaWidth, 0.0001), 0.0, 1.0), antialiased);
}
fn shapeSource(in: ItemOut) -> vec4f {
    let kind = in.info.x; let radius = in.info.y; let strokeWidth = in.info.z; let cap = in.info.w;
    var d: f32;
    if (kind < 1.5) { d = roundedBoxDistance(in.localPosition, in.size, 0.0); }
    else if (kind < 2.5) { d = mix(roundedBoxDistance(in.localPosition, in.size, radius), continuousRoundedBoxDistance(in.localPosition, in.size, radius), in.flags.z); }
    else if (kind < 3.5) { d = ellipseDistance(in.localPosition, in.size); }
    else if (cap > 1.5) { d = segmentDistance(in.localPosition, in.line.xy, in.line.zw) - strokeWidth * 0.5; }
    else { d = lineBoxDistance(in.localPosition, in.line.xy, in.line.zw, strokeWidth, cap); }
    var fillCoverage = coverage(d, in.flags.x) * in.fillColor.a;
    var strokeCoverage = coverage(abs(d + strokeWidth * 0.5) - strokeWidth * 0.5, in.flags.y) * in.strokeColor.a;
    if (kind > 3.5) { fillCoverage = 0.0; strokeCoverage = coverage(d, in.flags.y) * in.strokeColor.a; }
    let fill = vec4f(in.fillColor.rgb * fillCoverage, fillCoverage);
    let stroke = vec4f(in.strokeColor.rgb * strokeCoverage, strokeCoverage);
    return stroke + fill * (1.0 - stroke.a);
}
fn hueToRGB(p: f32, q: f32, input: f32) -> f32 {
    var t = input; if (t < 0.0) { t += 1.0; } if (t > 1.0) { t -= 1.0; }
    if (t < 1.0 / 6.0) { return p + (q - p) * 6.0 * t; }
    if (t < 0.5) { return q; } if (t < 2.0 / 3.0) { return p + (q - p) * (2.0 / 3.0 - t) * 6.0; }
    return p;
}
fn rgbToHSL(c: vec3f) -> vec3f {
    let hi = max(c.r, max(c.g, c.b)); let lo = min(c.r, min(c.g, c.b)); var h = 0.0; var s = 0.0; let l = (hi + lo) * 0.5;
    if (hi != lo) { let d = hi - lo; s = select(d / (hi + lo), d / (2.0 - hi - lo), l > 0.5);
        if (hi == c.r) { h = (c.g - c.b) / d + select(0.0, 6.0, c.g < c.b); }
        else if (hi == c.g) { h = (c.b - c.r) / d + 2.0; } else { h = (c.r - c.g) / d + 4.0; } h /= 6.0; }
    return vec3f(h, s, l);
}
fn hslToRGB(hsl: vec3f) -> vec3f {
    if (hsl.y == 0.0) { return vec3f(hsl.z); }
    let q = select(hsl.z + hsl.y - hsl.z * hsl.y, hsl.z * (1.0 + hsl.y), hsl.z < 0.5); let p = 2.0 * hsl.z - q;
    return vec3f(hueToRGB(p,q,hsl.x+1.0/3.0), hueToRGB(p,q,hsl.x), hueToRGB(p,q,hsl.x-1.0/3.0));
}
fn blendColor(mode: f32, s: vec3f, d: vec3f) -> vec3f {
    if (mode == 2.0) { return s*d; } if (mode == 3.0) { return s+d-s*d; }
    if (mode == 5.0 || mode == 11.0) { let a=select(s,d,mode==11.0); let b=select(d,s,mode==11.0); return mix(2.0*a*b,1.0-2.0*(1.0-a)*(1.0-b),step(vec3f(0.5),b)); }
    if (mode == 6.0) { return min(s,d); } if (mode == 7.0) { return max(s,d); }
    if (mode == 8.0) { return mix(min(d/max(vec3f(1.0)-s,vec3f(0.0001)),vec3f(1.0)),vec3f(1.0),step(vec3f(1.0),s)); }
    if (mode == 9.0) { return mix(vec3f(1.0)-min((vec3f(1.0)-d)/max(s,vec3f(0.0001)),vec3f(1.0)),vec3f(0.0),step(s,vec3f(0.0))); }
    if (mode == 10.0) { let x=mix(((16.0*d-12.0)*d+4.0)*d,sqrt(d),step(vec3f(0.25),d)); return mix(d-(1.0-2.0*s)*d*(1.0-d),d+(2.0*s-1.0)*(x-d),step(vec3f(0.5),s)); }
    if (mode == 12.0) { return abs(d-s); } if (mode == 13.0) { return d+s-2.0*d*s; }
    if (mode >= 14.0) { let sh=rgbToHSL(s); let dh=rgbToHSL(d); if(mode==14.0){return hslToRGB(vec3f(sh.x,dh.y,dh.z));} if(mode==15.0){return hslToRGB(vec3f(dh.x,sh.y,dh.z));} if(mode==16.0){return hslToRGB(vec3f(sh.x,sh.y,dh.z));} return hslToRGB(vec3f(dh.x,dh.y,sh.z)); }
    return s;
}
@fragment fn itemFragment(in: ItemOut) -> @location(0) vec4f {
    var source = select(vec4f(1.0), textureSample(itemTexture,itemSampler,in.texCoord), uniforms.useTexture > 0.5) * in.color;
    if (in.info.x >= 0.5) { source = shapeSource(in); } else { source = vec4f(source.rgb * source.a, source.a); }
    if (uniforms.sampled < 0.5) { return source; }
    let coord = vec2i(in.position.xy); let destination = textureLoad(sampledSceneTexture,coord,0);
    if (uniforms.blendMode == 4.0) { return source; } if (uniforms.blendMode == 1.0) { return source + destination; }
    let sc=select(vec3f(0.0),source.rgb/source.a,source.a>0.0); let dc=select(vec3f(0.0),destination.rgb/destination.a,destination.a>0.0);
    let blended=clamp(blendColor(uniforms.blendMode,sc,dc),vec3f(0.0),vec3f(1.0));
    return vec4f(blended*source.a+destination.rgb*(1.0-source.a),source.a+destination.a*(1.0-source.a));
}
"""

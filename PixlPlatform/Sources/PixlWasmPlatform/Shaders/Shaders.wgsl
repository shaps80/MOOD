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
    @location(9) modulationMode: u32,
}

struct SpriteVertexOutput {
    @builtin(position) position: vec4f,
    @location(0) tint: vec4f,
    @location(1) textureCoordinate: vec2f,
    @location(2) @interpolate(flat) modulationMode: u32,
}

@vertex
fn pixlSpriteVertex(input: SpriteVertexInput) -> SpriteVertexOutput {
    var output: SpriteVertexOutput;
    let world = input.transformX * input.position.x
        + input.transformY * input.position.y
        + input.translation;
    let projected = parameters.transform * vec3f(world, 1.0);
    output.position = vec4f(projected.xy, 0.0, 1.0);
    output.tint = input.tint;
    output.textureCoordinate = input.textureOrigin
        + input.textureCoordinate * input.textureScale;
    output.modulationMode = input.modulationMode;
    return output;
}

@fragment
fn pixlSpriteFragment(input: SpriteVertexOutput) -> @location(0) vec4f {
    let sampled = textureSample(texture, textureSampler, input.textureCoordinate);
    let alphaMask = (input.modulationMode & 1u) != 0u;
    let premultiplied = (input.modulationMode & 2u) != 0u;
    if alphaMask {
        let alpha = sampled.a * input.tint.a;
        if premultiplied {
            return vec4f(input.tint.rgb * alpha, alpha);
        }
        return vec4f(input.tint.rgb, alpha);
    }
    var result = sampled * input.tint;
    if premultiplied {
        result = vec4f(result.rgb * input.tint.a, result.a);
    }
    return result;
}

struct ShapeVertexInput {
    @location(0) position: vec2f,
    @location(3) transformX: vec2f,
    @location(4) transformY: vec2f,
    @location(5) translation: vec2f,
    @location(6) parameters: vec4f,
    @location(7) fillColor: vec4f,
    @location(8) strokeColor: vec4f,
    @location(9) style: vec4f,
    @location(10) quadHalfExtent: vec2f,
}

struct ShapeVertexOutput {
    @builtin(position) position: vec4f,
    @location(0) localPosition: vec2f,
    @location(1) @interpolate(flat) parameters: vec4f,
    @location(2) @interpolate(flat) fillColor: vec4f,
    @location(3) @interpolate(flat) strokeColor: vec4f,
    @location(4) @interpolate(flat) style: vec4f,
}

@vertex
fn pixlShapeVertex(input: ShapeVertexInput) -> ShapeVertexOutput {
    var output: ShapeVertexOutput;
    let world = input.transformX * input.position.x
        + input.transformY * input.position.y
        + input.translation;
    let projected = parameters.transform * vec3f(world, 1.0);
    output.position = vec4f(projected.xy, 0.0, 1.0);
    output.localPosition = input.position * input.quadHalfExtent * 2.0;
    output.parameters = input.parameters;
    output.fillColor = input.fillColor;
    output.strokeColor = input.strokeColor;
    output.style = input.style;
    return output;
}

struct ExtendedShapeVertexInput {
    @location(0) position: vec2f,
    @location(3) transformX: vec2f,
    @location(4) transformY: vec2f,
    @location(5) translation: vec2f,
    @location(6) parameters: vec4f,
    @location(7) extendedParameters: vec4f,
    @location(8) fillColor: vec4f,
    @location(9) strokeColor: vec4f,
    @location(10) style: vec4f,
    @location(11) quadHalfExtent: vec2f,
}

struct ExtendedShapeVertexOutput {
    @builtin(position) position: vec4f,
    @location(0) localPosition: vec2f,
    @location(1) @interpolate(flat) parameters: vec4f,
    @location(2) @interpolate(flat) extendedParameters: vec4f,
    @location(3) @interpolate(flat) fillColor: vec4f,
    @location(4) @interpolate(flat) strokeColor: vec4f,
    @location(5) @interpolate(flat) style: vec4f,
}

@vertex
fn pixlExtendedShapeVertex(input: ExtendedShapeVertexInput) -> ExtendedShapeVertexOutput {
    var output: ExtendedShapeVertexOutput;
    let world = input.transformX * input.position.x
        + input.transformY * input.position.y + input.translation;
    let projected = parameters.transform * vec3f(world, 1.0);
    output.position = vec4f(projected.xy, 0.0, 1.0);
    output.localPosition = input.position * input.quadHalfExtent * 2.0;
    output.parameters = input.parameters;
    output.extendedParameters = input.extendedParameters;
    output.fillColor = input.fillColor;
    output.strokeColor = input.strokeColor;
    output.style = input.style;
    return output;
}

struct PrimitiveShapeVertexInput {
    @location(0) position: vec2f,
    @location(1) previous: vec2f,
    @location(2) next: vec2f,
    @location(3) side: f32,
    @location(4) transformX: vec2f,
    @location(5) transformY: vec2f,
    @location(6) translation: vec2f,
    @location(7) origin: vec2f,
    @location(8) size: vec2f,
    @location(9) width: f32,
    @location(10) color: vec4f,
}

struct PrimitiveShapeVertexOutput {
    @builtin(position) position: vec4f,
    @location(0) @interpolate(flat) color: vec4f,
}

fn pixlPrimitiveProjected(
    normalized: vec2f,
    input: PrimitiveShapeVertexInput
) -> vec2f {
    let local = input.origin + normalized * input.size;
    let world = input.transformX * local.x
        + input.transformY * local.y
        + input.translation;
    return (parameters.transform * vec3f(world, 1.0)).xy;
}

@vertex
fn pixlPrimitiveShapeVertex(input: PrimitiveShapeVertexInput) -> PrimitiveShapeVertexOutput {
    var projected = pixlPrimitiveProjected(input.position, input);
    if input.side != 0.0 {
        // Sprite workspaces place logical view size in this shared parameter slot.
        let logicalSize = parameters.textureOrigin;
        let current = projected * logicalSize * 0.5;
        let previous = pixlPrimitiveProjected(input.previous, input) * logicalSize * 0.5;
        let next = pixlPrimitiveProjected(input.next, input) * logicalSize * 0.5;
        let incoming = normalize(current - previous);
        let outgoing = normalize(next - current);
        let crossValue = incoming.x * outgoing.y - incoming.y * outgoing.x;
        var orientation = -1.0;
        if crossValue >= 0.0 { orientation = 1.0; }
        let incomingNormal = vec2f(incoming.y, -incoming.x) * orientation;
        let outgoingNormal = vec2f(outgoing.y, -outgoing.x) * orientation;
        let miter = normalize(incomingNormal + outgoingNormal);
        let miterLength = input.width * 0.5
            / max(abs(dot(miter, outgoingNormal)), 0.0001);
        projected += miter * miterLength * input.side * 2.0 / logicalSize;
    }
    var output: PrimitiveShapeVertexOutput;
    output.position = vec4f(projected, 0.0, 1.0);
    output.color = input.color;
    return output;
}

@fragment
fn pixlPrimitiveShapeFragment(input: PrimitiveShapeVertexOutput) -> @location(0) vec4f {
    return input.color;
}

struct PolygonVertexInput {
    @location(0) position: vec2f,
    @location(3) transformX: vec2f,
    @location(4) transformY: vec2f,
    @location(5) translation: vec2f,
    @location(6) color: vec4f,
}

struct PolygonVertexOutput {
    @builtin(position) position: vec4f,
    @location(0) @interpolate(flat) color: vec4f,
}

@vertex
fn pixlPolygonVertex(input: PolygonVertexInput) -> PolygonVertexOutput {
    let world = input.transformX * input.position.x
        + input.transformY * input.position.y
        + input.translation;
    let projected = parameters.transform * vec3f(world, 1.0);
    var output: PolygonVertexOutput;
    output.position = vec4f(projected.xy, 0.0, 1.0);
    output.color = input.color;
    return output;
}

@fragment
fn pixlPolygonFragment(input: PolygonVertexOutput) -> @location(0) vec4f {
    return input.color;
}

fn pixlRoundedBoxDistance(point: vec2f, halfSize: vec2f, rounding: f32) -> f32 {
    let q = abs(point) - halfSize + rounding;
    return length(max(q, vec2f(0.0))) + min(max(q.x, q.y), 0.0) - rounding;
}

fn pixlContinuousRoundedBoxDistance(point: vec2f, halfSize: vec2f, rounding: f32) -> f32 {
    let outerHalfSize = halfSize + rounding;
    let extent = min(rounding * 1.5286648, min(outerHalfSize.x, outerHalfSize.y));
    let q = abs(point) - (outerHalfSize - extent);
    let outside = max(q, vec2f(0.0));
    let outside2 = outside * outside;
    let continuous = pow(
        max(outside2.x * outside.x + outside2.y * outside.y, 0.0),
        1.0 / 3.0
    );
    return continuous + min(max(q.x, q.y), 0.0) - extent;
}

fn pixlUnevenContinuousRoundedBoxDistance(point:vec2f,halfSize:vec2f,radii:vec4f)->f32{
    var radius=radii.x;
    if(point.y<0.){radius=select(radii.x,radii.y,point.x>=0.);}else{radius=select(radii.z,radii.w,point.x>=0.);}
    let extent=min(radius*1.5286648,min(halfSize.x,halfSize.y));
    let q=abs(point)-(halfSize-extent);let outside=max(q,vec2f(0.));let outside2=outside*outside;
    let continuous=pow(max(outside2.x*outside.x+outside2.y*outside.y,0.),1./3.);
    return continuous+min(max(q.x,q.y),0.)-extent;
}

fn pixlSegmentDistance(p:vec2f,a:vec2f,b:vec2f)->f32{let pa=p-a;let ba=b-a;let h=clamp(dot(pa,ba)/dot(ba,ba),0.,1.);return length(pa-ba*h);}
fn pixlRhombusDistance(p0:vec2f,b:vec2f)->f32{let p=abs(p0);let h=clamp((-2.*dot(p,vec2f(b.x,-b.y))+dot(b,vec2f(b.x,-b.y)))/dot(b,b),-1.,1.);let d=length(p-.5*b*vec2f(1.-h,1.+h));return d*sign(p.x*b.y+p.y*b.x-b.x*b.y);}
fn pixlTrapezoidDistance(p0:vec2f,r1:f32,r2:f32,he:f32)->f32{let k1=vec2f(r2,he);let k2=vec2f(r2-r1,2.*he);let p=vec2f(abs(p0.x),p0.y);let ca=vec2f(p.x-min(p.x,select(r2,r1,p.y<0.)),abs(p.y)-he);let cb=p-k1+k2*clamp(dot(k1-p,k2)/dot(k2,k2),0.,1.);let s=select(1.,-1.,cb.x<0.&&ca.y<0.);return s*sqrt(min(dot(ca,ca),dot(cb,cb)));}
fn pixlParallelogramDistance(p0:vec2f,wi:f32,he:f32,sk:f32)->f32{let e=vec2f(sk,he);var p=select(p0,-p0,p0.y<0.);var w=p-e;w.x-=clamp(w.x,-wi,wi);var d=vec2f(dot(w,w),-w.y);let s=p.x*e.y-p.y*e.x;p=select(p,-p,s<0.);var v=p-vec2f(wi,0.);v-=e*clamp(dot(v,e)/dot(e,e),-1.,1.);d=min(d,vec2f(dot(v,v),wi*he-abs(s)));return sqrt(d.x)*sign(-d.y);}
fn pixlEquilateralTriangleDistance(p0:vec2f,r:f32)->f32{let k=1.7320508075688772;var p=vec2f(p0.x,p0.y+r*.2886751346)/r;p.x=abs(p.x)-1.;p.y+=1./k;if(p.x+k*p.y>0.){p=vec2f(p.x-k*p.y,-k*p.x-p.y)*.5;}p.x-=clamp(p.x,-2.,0.);return -length(p)*sign(p.y)*r;}
fn pixlIsoscelesTriangleDistance(p0:vec2f,c:vec2f)->f32{let p=vec2f(p0.x,p0.y+c.y*.5);let q=vec2f(abs(p.x),p.y);let a=q-c*clamp(dot(q,c)/dot(c,c),0.,1.);let b=q-c*vec2f(clamp(q.x/c.x,0.,1.),1.);let s=-sign(c.y);let d=min(vec2f(dot(a,a),s*(q.x*c.y-q.y*c.x)),vec2f(dot(b,b),s*(q.y-c.y)));return -sqrt(d.x)*sign(d.y);}
fn pixlUnevenCapsuleDistance(p0:vec2f,r1:f32,r2:f32,h:f32)->f32{let p=vec2f(p0.x,p0.y+(h+r2-r1)*.5);let q=vec2f(abs(p.x),p.y);let b=(r1-r2)/h;let a=sqrt(1.-b*b);let k=dot(q,vec2f(-b,a));if(k<0.){return length(q)-r1;}if(k>a*h){return length(q-vec2f(0.,h))-r2;}return dot(q,vec2f(a,b))-r1;}
fn pixlPentagonDistance(p0:vec2f,r:f32)->f32{let k=vec3f(.809016994,.587785252,.726542528);var p=vec2f(abs(p0.x),p0.y);p-=2.*min(dot(vec2f(-k.x,k.y),p),0.)*vec2f(-k.x,k.y);p-=2.*min(dot(k.xy,p),0.)*k.xy;p-=vec2f(clamp(p.x,-r*k.z,r*k.z),r);return length(p)*sign(p.y);}
fn pixlHexagonDistance(p0:vec2f,r:f32)->f32{let k=vec3f(-.866025404,.5,.577350269);var p=abs(p0);p-=2.*min(dot(k.xy,p),0.)*k.xy;p-=vec2f(clamp(p.x,-k.z*r,k.z*r),r);return length(p)*sign(p.y);}
fn pixlOctagonDistance(p0:vec2f,r:f32)->f32{let k=vec3f(-.9238795325,.3826834323,.4142135623);var p=abs(p0);p-=2.*min(dot(k.xy,p),0.)*k.xy;p-=2.*min(dot(vec2f(-k.x,k.y),p),0.)*vec2f(-k.x,k.y);p-=vec2f(clamp(p.x,-k.z*r,k.z*r),r);return length(p)*sign(p.y);}
fn pixlHexagramDistance(p0:vec2f,r:f32)->f32{let k=vec4f(-.5,.8660254038,.5773502692,1.7320508076);var p=abs(p0);p-=2.*min(dot(k.xy,p),0.)*k.xy;p-=2.*min(dot(k.yx,p),0.)*k.yx;p-=vec2f(clamp(p.x,r*k.z,r*k.w),r);return length(p)*sign(p.y);}
fn pixlStarDistance(p0:vec2f,r:f32,n:f32,inner:f32)->f32{let an=3.14159265/n;let en=atan2(sin(an),cos(an)-inner);let acs=vec2f(cos(an),sin(an));let ecs=vec2f(cos(en),sin(en));let a=atan2(abs(p0.x),p0.y);let period=2.*an;let bn=(a-floor(a/period)*period)-an;var p=length(p0)*vec2f(cos(bn),abs(sin(bn)));p-=r*acs;p+=ecs*clamp(-dot(p,ecs),0.,r*acs.y/ecs.y);return length(p)*sign(p.x);}
fn pixlPieDistance(p0:vec2f,r:f32,angle:f32)->f32{let sc=vec2f(sin(angle),cos(angle));let p=vec2f(abs(p0.x),p0.y);let l=length(p)-r;let m=length(p-sc*clamp(dot(p,sc),0.,r));return max(l,m*sign(sc.y*p.x-sc.x*p.y));}
fn pixlVesicaDistance(p0:vec2f,r:f32,d:f32)->f32{let p=abs(p0);let b=sqrt(r*r-d*d);return select(length(p-vec2f(-d,0.))-r,length(p-vec2f(0.,b)),(p.y-b)*d>p.x*b);}
fn pixlMoonDistance(p0:vec2f,d:f32,ra:f32,rb:f32)->f32{let p=vec2f(p0.x,abs(p0.y));let a=(ra*ra-rb*rb+d*d)/(2.*d);let b=sqrt(max(ra*ra-a*a,0.));if(d*(p.x*b-p.y*a)>d*d*max(b-p.y,0.)){return length(p-vec2f(a,b));}return max(length(p)-ra,-(length(p-vec2f(d,0.))-rb));}
fn pixlEggDistance(p0:vec2f,ra:f32,rb:f32)->f32{let k=1.7320508075688772;let r=ra-rb;let top=k*r+rb;let p=vec2f(abs(p0.x),p0.y+(top-ra)*.5);if(p.y<0.){return length(p)-r-rb;}if(k*(p.x+r)<p.y){return length(vec2f(p.x,p.y-k*r))-rb;}return length(vec2f(p.x+r,p.y))-2.*r-rb;}
fn pixlHeartDistance(p0:vec2f,scale:f32)->f32{let shifted=vec2f(p0.x,p0.y+.551776695*scale);let p=vec2f(abs(shifted.x/scale),shifted.y/scale);if(p.x+p.y>1.){return (length(p-vec2f(.25,.75))-.3535533906)*scale;}let u=p-vec2f(0.,1.);let v=p-.5*max(p.x+p.y,0.);return sqrt(min(dot(u,u),dot(v,v)))*sign(p.x-p.y)*scale;}
fn pixlCrossDistance(p0:vec2f,b:vec2f)->f32{var p=abs(p0);p=select(p,p.yx,p.y>p.x);let q=p-b;let k=max(q.y,q.x);let w=select(vec2f(b.y-p.x,-k),q,k>0.);return sign(k)*length(max(w,vec2f(0.)));}
fn pixlRoundedXDistance(p0:vec2f,w:f32,r:f32)->f32{let p=abs(p0);return length(p-min(p.x+p.y,w)*.5)-r;}
fn pixlCubeRoot(v:f32)->f32{return sign(v)*pow(abs(v),1./3.);}
fn pixlCutDiskDistance(p0:vec2f,r:f32,h:f32)->f32{let w=sqrt(max(r*r-h*h,0.));let p=vec2f(abs(p0.x),p0.y);let s=max((h-r)*p.x*p.x+w*w*(h+r-2.*p.y),h*p.x-w*p.y);if(s<0.){return length(p)-r;}return select(length(p-vec2f(w,h)),h-p.y,p.x<w);}
fn pixlArcDistance(p0:vec2f,angle:f32,r:f32,w:f32)->f32{let sc=vec2f(sin(angle),cos(angle));let p=vec2f(abs(p0.x),p0.y);let k=select(length(p),dot(p,sc),sc.y*p.x>sc.x*p.y);return sqrt(max(dot(p,p)+r*r-2.*r*k,0.))-w;}
fn pixlRingDistance(p0:vec2f,n0:vec2f,r:f32,w:f32)->f32{var p=vec2f(abs(p0.x),p0.y);let n=normalize(n0);p=vec2f(n.x*p.x-n.y*p.y,n.y*p.x+n.x*p.y);return max(abs(length(p)-r)-w,length(vec2f(p.x,max(0.,abs(r-p.y)-w)))*sign(p.x));}
fn pixlHorseshoeDistance(p0:vec2f,angle:f32,r:f32,le:f32,w:f32)->f32{let c=vec2f(cos(angle),sin(angle));var p=vec2f(abs(p0.x),p0.y);let l=length(p);p=vec2f(-c.x*p.x+c.y*p.y,c.y*p.x+c.x*p.y);p=vec2f(select(l*sign(-c.x),p.x,p.y>0.||p.x>0.),select(l,p.y,p.x>0.));p=vec2f(p.x-le,abs(p.y-r)-w);return length(max(p,vec2f(0.)))+min(0.,max(p.x,p.y));}
fn pixlRoundedCrossDistance(p0:vec2f,h:f32)->f32{let k=.5*(h+1./h);let p=abs(p0);if(p.x<1.&&p.y<p.x*(k-h)+h){return k-length(p-vec2f(1.,k));}let a=p-vec2f(0.,h);let b=p-vec2f(1.,0.);return sqrt(min(dot(a,a),dot(b,b)));}
fn pixlEllipseDistance(p:vec2f,ab:vec2f)->f32{let k0=length(p/ab);let k1=length(p/(ab*ab));return k0*(k0-1.)/max(k1,0.000001);}
fn pixlParabolaDistance(pos0:vec2f,k0:f32,halfSize:vec2f)->f32{let direction=sign(k0);let k=abs(k0);let pos=vec2f(abs(pos0.x),pos0.y*direction);let ik=1./k;let pp=ik*(pos.y-.5*ik)/3.;let q=.25*ik*ik*pos.x;let h=q*q-pp*pp*pp;let r=sqrt(abs(h));var x=2.*cos(atan2(r,q)/3.)*sqrt(max(pp,0.));if(h>0.){x=pixlCubeRoot(q+r)-pixlCubeRoot(r-q);}let limit=min(halfSize.x,sqrt(max(halfSize.y/k,0.)));x=clamp(x,0.,limit);return length(pos-vec2f(x,k*x*x));}
fn pixlParabolaSegmentDistance(pos0:vec2f,wi:f32,he:f32)->f32{let pos=vec2f(abs(pos0.x),pos0.y+he*.5);let ik=wi*wi/he;let p=ik*(he-pos.y-.5*ik)/3.;let q=pos.x*ik*ik*.25;let h=q*q-p*p*p;let r=sqrt(abs(h));var x=2.*cos(atan2(r,q)/3.)*sqrt(max(p,0.));if(h>0.){x=pixlCubeRoot(q+r)-pixlCubeRoot(r-q);}x=min(x,wi);let curve=length(pos-vec2f(x,he-x*x/ik))*sign(ik*(pos.y-he)+pos.x*pos.x);return max(curve,-pos.y);}
fn pixlBlobbyCrossDistance(pos0:vec2f,he:f32)->f32{let a=abs(pos0*2.);let pos=vec2f(abs(a.x-a.y),1.-a.x-a.y)*.7071067811865476;let p=(he-pos.y-.25/he)/(6.*he);let q=pos.x/(he*he*16.);let h=q*q-p*p*p;var x=2.*sqrt(max(p,0.))*cos(acos(clamp(q/(p*sqrt(max(p,.000001))),-1.,1.))/3.);if(h>0.){let r=sqrt(h);x=pixlCubeRoot(q+r)-pixlCubeRoot(r-q);}x=min(x,.7071067811865476);let z=vec2f(x,he*(1.-2.*x*x))-pos;return length(z)*sign(z.y)*.5;}
fn pixlTunnelDistance(p0:vec2f,wh:vec2f)->f32{let centered=vec2f(p0.x,p0.y+(wh.x-wh.y)*.5);let p=vec2f(abs(centered.x),-centered.y);var q=p-wh;let a=vec2f(max(q.x,0.),q.y);let d1=dot(a,a);q.x=select(length(p)-wh.x,q.x,p.y>0.);let b=vec2f(q.x,max(q.y,0.));let d=sqrt(min(d1,dot(b,b)));return select(d,-d,max(q.x,q.y)<0.);}
fn pixlStairsDistance(p:vec2f,wh:vec2f,n:f32)->f32{let ba=wh*n;let q=p+ba*.5;var d=min(pixlSegmentDistance(q,vec2f(0.),vec2f(ba.x,0.)),pixlSegmentDistance(q,vec2f(ba.x,0.),ba));for(var i=0u;f32(i)<n;i++){let hi=vec2f(ba.x-f32(i)*wh.x,ba.y-f32(i)*wh.y);let lo=hi-wh;d=min(d,pixlSegmentDistance(q,hi,vec2f(lo.x,hi.y)));d=min(d,pixlSegmentDistance(q,vec2f(lo.x,hi.y),lo));}let stepTop=ceil(clamp(q.x,0.,ba.x)/wh.x)*wh.y;let inside=q.x>=0.&&q.x<=ba.x&&q.y>=0.&&q.y<=stepTop;return select(d,-d,inside);}
fn pixlQuadraticCircleDistance(p0:vec2f,size:f32)->f32{let a=size*.5;let q=abs(p0);var t=clamp(atan2(q.y*q.y,q.x*q.x),.0001,1.5706963268);for(var i=0u;i<5u;i++){let c=cos(t);let s=sin(t);let rc=sqrt(c);let rs=sqrt(s);let point=a*vec2f(rc,rs);let first=.5*a*vec2f(-s/rc,c/rs);let second=-.5*a*vec2f(rc+.5*s*s/(c*rc),rs+.5*c*c/(s*rs));let delta=point-q;let g=dot(delta,first);let gp=dot(first,first)+dot(delta,second);t=clamp(t-g/max(gp,.000001),.0001,1.5706963268);}let nearest=a*sqrt(vec2f(cos(t),sin(t)));let d=min(length(q-nearest),min(length(q-vec2f(a,0.)),length(q-vec2f(0.,a))));let q2=q*q;return d*sign(q2.x*q2.x+q2.y*q2.y-a*a*a*a);}
fn pixlHyperbolaDistance(p0:vec2f,scale:f32,halfSize:vec2f)->f32{let p=abs(p0);let lo=scale/halfSize.y;let hi=halfSize.x;if(lo>hi){return 1e6;}var x=clamp(max(p.x,sqrt(scale)),lo,hi);for(var i=0u;i<5u;i++){let y=scale/x;let h=y-p.y;let x2=x*x;let g=(x-p.x)-scale*h/x2;let gp=1.+(scale*scale)/(x2*x2)+2.*scale*h/(x2*x);x=clamp(x-g/max(gp,.000001),lo,hi);}return length(p-vec2f(x,scale/x));}
fn pixlCoolSDistance(p0:vec2f,size:f32)->f32{let p=p0/size;let d0=pixlQuadraticBezierDistance(p,vec2f(.35,.5),vec2f(-.35,.5),vec2f(-.35,.25));let d1=pixlQuadraticBezierDistance(p,vec2f(-.35,.25),vec2f(-.35,0.),vec2f(0.));let d2=pixlQuadraticBezierDistance(p,vec2f(0.),vec2f(.35,0.),vec2f(.35,-.25));let d3=pixlQuadraticBezierDistance(p,vec2f(.35,-.25),vec2f(.35,-.5),vec2f(-.35,-.5));return min(min(d0,d1),min(d2,d3))*size;}
fn pixlCircleWaveDistance(p:vec2f,r:f32,w:f32)->f32{let a=atan2(p.y,p.x);let wave=sin(a*6.)*w*.5;return abs(length(p)-(r+wave))-w*.5;}
fn pixlTriangleDistance(p:vec2f,p0:vec2f,p1:vec2f,p2:vec2f)->f32{let e0=p1-p0;let e1=p2-p1;let e2=p0-p2;let v0=p-p0;let v1=p-p1;let v2=p-p2;let q0=v0-e0*clamp(dot(v0,e0)/dot(e0,e0),0.,1.);let q1=v1-e1*clamp(dot(v1,e1)/dot(e1,e1),0.,1.);let q2=v2-e2*clamp(dot(v2,e2)/dot(e2,e2),0.,1.);let s=sign(e0.x*e2.y-e0.y*e2.x);let d=min(min(vec2f(dot(q0,q0),s*(v0.x*e0.y-v0.y*e0.x)),vec2f(dot(q1,q1),s*(v1.x*e1.y-v1.y*e1.x))),vec2f(dot(q2,q2),s*(v2.x*e2.y-v2.y*e2.x)));return -sqrt(d.x)*sign(d.y);}
fn pixlQuadraticBezierDistance(pos:vec2f,A:vec2f,B:vec2f,C:vec2f)->f32{let a=B-A;let b=A-2.*B+C;let c=a*2.;let d=A-pos;let kk=1./dot(b,b);let kx=kk*dot(a,b);let ky=kk*(2.*dot(a,a)+dot(d,b))/3.;let kz=kk*dot(d,a);let p=ky-kx*kx;let p3=p*p*p;let q=kx*(2.*kx*kx-3.*ky)+kz;var h=q*q+4.*p3;var result=0.;if(h>=0.){h=sqrt(h);let x=(vec2f(h,-h)-q)*.5;let uv=sign(x)*pow(abs(x),vec2f(1./3.));let t=clamp(uv.x+uv.y-kx,0.,1.);let qos=d+(c+b*t)*t;result=dot(qos,qos);}else{let z=sqrt(-p);let v=acos(clamp(q/(p*z*2.),-1.,1.))/3.;let m=cos(v);let n=sin(v)*1.7320508075688772;let t=clamp(vec3f(m+m,-n-m,n-m)*z-kx,vec3f(0.),vec3f(1.));let q0=d+(c+b*t.x)*t.x;let q1=d+(c+b*t.y)*t.y;let q2=d+(c+b*t.z)*t.z;result=min(dot(q0,q0),min(dot(q1,q1),dot(q2,q2)));}return sqrt(result);}

fn pixlCompactShapeDistance(kind:u32,p:vec2f,v:vec4f)->f32{
    switch kind {
        case 0u:{return length(p)-v.x;} case 1u:{return pixlRoundedBoxDistance(p,v.xy,v.z);}
        case 2u:{return pixlSegmentDistance(p,v.xy,v.zw);} case 3u:{return pixlRhombusDistance(p,v.xy);}
        case 4u:{return pixlTrapezoidDistance(p,v.x,v.y,v.z);} case 5u:{return pixlParallelogramDistance(p,v.x,v.y,v.z);}
        case 6u:{return pixlEquilateralTriangleDistance(p,v.x);} case 7u:{return pixlIsoscelesTriangleDistance(p,v.xy);}
        case 9u:{return pixlUnevenCapsuleDistance(p,v.x,v.y,v.z);} case 10u:{return pixlPentagonDistance(p,v.x);}
        case 11u:{return pixlHexagonDistance(p,v.x);} case 12u:{return pixlOctagonDistance(p,v.x);}
        case 13u:{return pixlHexagramDistance(p,v.x);} case 14u:{return pixlStarDistance(p,v.x,v.y,v.z);}
        case 15u:{return pixlPieDistance(p,v.x,v.y);} case 16u:{return pixlCutDiskDistance(p,v.x,v.y);}
        case 17u:{return pixlArcDistance(p,v.y,v.x,v.z);} case 18u:{return pixlRingDistance(p,v.zw,v.x,v.y);}
        case 19u:{return pixlHorseshoeDistance(p,v.y,v.x,v.z,v.w);} case 20u:{return pixlVesicaDistance(p,v.x,v.y);}
        case 21u:{return pixlMoonDistance(p,v.x,v.y,v.z);} case 22u:{return pixlRoundedCrossDistance(p,v.x);}
        case 23u:{return pixlEggDistance(p,v.x,v.y);}
        case 24u:{return pixlHeartDistance(p,v.x);} case 25u:{return pixlCrossDistance(p,v.xy);}
        case 26u:{return pixlRoundedXDistance(p,v.x,v.y);} case 27u:{return pixlEllipseDistance(p,v.xy);}
        case 28u:{return pixlParabolaDistance(p,v.x,v.yz);} case 29u:{return pixlParabolaSegmentDistance(p,v.x,v.y);}
        case 31u:{return pixlBlobbyCrossDistance(p,v.x);} case 32u:{return pixlTunnelDistance(p,v.xy);}
        case 33u:{return pixlStairsDistance(p,v.xy,v.z);} case 34u:{return pixlQuadraticCircleDistance(p,v.x);}
        case 35u:{return pixlHyperbolaDistance(p,v.x,v.yz);} case 36u:{return pixlCoolSDistance(p,v.x);}
        case 37u:{return pixlCircleWaveDistance(p,v.x,v.y);} default:{return pixlRoundedBoxDistance(p,v.xy,v.z);}
    }
}

fn pixlShapeDistance(kind:u32,point:vec2f,parameters:vec4f,rounding:f32)->f32{
    if(kind==1u && parameters.z>0.5){return pixlContinuousRoundedBoxDistance(point,parameters.xy,rounding);}
    return pixlCompactShapeDistance(kind,point,parameters)-rounding;
}

@fragment
fn pixlShapeFragment(input: ShapeVertexOutput) -> @location(0) vec4f {
    let kind = u32(input.style.x + 0.5);
    let distance = pixlShapeDistance(kind,input.localPosition,input.parameters,input.style.w);
    let width = input.style.y;
    let isSmooth=input.style.z>2.;let alignment=input.style.z-select(0.,4.,isSmooth);
    let aa = max(fwidth(distance) * 0.5, 0.00001);
    let outer=select(select(width*.5,width,alignment>.5),0.,alignment<-.5);let inner=select(select(-width*.5,0.,alignment>.5),-width,alignment<-.5);
    let total=select(select(0.,1.,distance<=outer),1.-smoothstep(outer-aa,outer+aa,distance),isSmooth);
    let fillCoverage=select(select(0.,1.,distance<=inner),1.-smoothstep(inner-aa,inner+aa,distance),isSmooth);
    let strokeCoverage=select(0.,max(total-fillCoverage,0.),width>0.);
    let fill = input.fillColor * fillCoverage;
    let stroke = input.strokeColor * strokeCoverage;
    return stroke + fill;
}

@fragment
fn pixlGradientShapeFragment(input: ShapeVertexOutput) -> @location(0) vec4f {
    let packed=u32(input.style.x+.5);let kind=packed&63u;let row=((packed/64u)&255u)-1u;let placement=packed/16384u;
    let distance=pixlShapeDistance(kind,input.localPosition,input.parameters,input.style.w);
    let width=input.style.y;let isSmooth=input.style.z>2.;let alignment=input.style.z-select(0.,4.,isSmooth);let aa=max(fwidth(distance)*.5,.00001);let outer=select(select(width*.5,width,alignment>.5),0.,alignment<-.5);let inner=select(select(-width*.5,0.,alignment>.5),-width,alignment<-.5);let total=select(select(0.,1.,distance<=outer),1.-smoothstep(outer-aa,outer+aa,distance),isSmooth);let fillCoverage=select(select(0.,1.,distance<=inner),1.-smoothstep(inner-aa,inner+aa,distance),isSmooth);let strokeCoverage=select(0.,max(total-fillCoverage,0.),width>0.);
    let start=input.fillColor.xy;let end=input.fillColor.zw;let delta=end-start;var t=dot(input.localPosition-start,delta)/dot(delta,delta);
    if(placement==1u){t=length(input.localPosition-start)/input.fillColor.z;}else if(placement==2u){t=fract((atan2(input.localPosition.y-start.y,input.localPosition.x-start.x)-input.fillColor.z)/6.28318530718);}t=clamp(t,0.,1.);
    let height=f32(textureDimensions(texture).y);let fill=textureSample(texture,textureSampler,vec2f(t,(f32(row)+.5)/height))*fillCoverage;let stroke=input.strokeColor*strokeCoverage;
    return stroke+fill;
}

@fragment
fn pixlExtendedShapeFragment(input: ExtendedShapeVertexOutput) -> @location(0) vec4f {
    let kind = u32(input.style.x + 0.5);
    var distance = pixlQuadraticBezierDistance(
        input.localPosition,input.parameters.xy,input.parameters.zw,input.extendedParameters.xy
    );
    if kind == 8u {
        distance = pixlTriangleDistance(
            input.localPosition,input.parameters.xy,input.parameters.zw,input.extendedParameters.xy
        );
    } else if kind == 38u {
        distance = pixlUnevenContinuousRoundedBoxDistance(
            input.localPosition,input.parameters.xy,vec4f(input.parameters.zw,input.extendedParameters.xy)
        );
    }
    distance-=input.style.w;
    let width = input.style.y;
    let isSmooth=input.style.z>2.;let alignment=input.style.z-select(0.,4.,isSmooth);
    let aa = max(fwidth(distance) * 0.5, 0.00001);
    let outer=select(select(width*.5,width,alignment>.5),0.,alignment<-.5);let inner=select(select(-width*.5,0.,alignment>.5),-width,alignment<-.5);let total=select(select(0.,1.,distance<=outer),1.-smoothstep(outer-aa,outer+aa,distance),isSmooth);let fillCoverage=select(select(0.,1.,distance<=inner),1.-smoothstep(inner-aa,inner+aa,distance),isSmooth);let strokeCoverage=select(0.,max(total-fillCoverage,0.),width>0.);
    let fill=input.fillColor*fillCoverage;
    let stroke=input.strokeColor*strokeCoverage;
    return stroke+fill;
}

@fragment
fn pixlGradientExtendedShapeFragment(input: ExtendedShapeVertexOutput) -> @location(0) vec4f {
    let packed=u32(input.style.x+.5);let kind=packed&63u;let row=((packed/64u)&255u)-1u;let placement=packed/16384u;
    var distance=pixlQuadraticBezierDistance(input.localPosition,input.parameters.xy,input.parameters.zw,input.extendedParameters.xy);
    if(kind==8u){distance=pixlTriangleDistance(input.localPosition,input.parameters.xy,input.parameters.zw,input.extendedParameters.xy);}
    else if(kind==38u){distance=pixlUnevenContinuousRoundedBoxDistance(input.localPosition,input.parameters.xy,vec4f(input.parameters.zw,input.extendedParameters.xy));}
    distance-=input.style.w;let width=input.style.y;let isSmooth=input.style.z>2.;let alignment=input.style.z-select(0.,4.,isSmooth);let aa=max(fwidth(distance)*.5,.00001);let outer=select(select(width*.5,width,alignment>.5),0.,alignment<-.5);let inner=select(select(-width*.5,0.,alignment>.5),-width,alignment<-.5);let total=select(select(0.,1.,distance<=outer),1.-smoothstep(outer-aa,outer+aa,distance),isSmooth);let fillCoverage=select(select(0.,1.,distance<=inner),1.-smoothstep(inner-aa,inner+aa,distance),isSmooth);let strokeCoverage=select(0.,max(total-fillCoverage,0.),width>0.);
    let start=input.fillColor.xy;let end=input.fillColor.zw;let delta=end-start;var t=dot(input.localPosition-start,delta)/dot(delta,delta);
    if(placement==1u){t=length(input.localPosition-start)/input.fillColor.z;}else if(placement==2u){t=fract((atan2(input.localPosition.y-start.y,input.localPosition.x-start.x)-input.fillColor.z)/6.28318530718);}t=clamp(t,0.,1.);
    let height=f32(textureDimensions(texture).y);let fill=textureSample(texture,textureSampler,vec2f(t,(f32(row)+.5)/height))*fillCoverage;let stroke=input.strokeColor*strokeCoverage;
    return stroke+fill;
}

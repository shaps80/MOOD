#include <metal_stdlib>
using namespace metal;

struct VertexOutput {
    float4 position [[position]];
    float4 color;
    float2 textureCoordinate;
};

struct VertexInput {
    float2 position [[attribute(0)]];
    float4 color [[attribute(1)]];
    float2 textureCoordinate [[attribute(2)]];
};

struct PrimitiveParameters {
    float3x3 transform;
    float2 textureOrigin;
    float2 textureScale;
};

vertex VertexOutput pixlVertex(
    VertexInput input [[stage_in]],
    constant PrimitiveParameters &parameters [[buffer(1)]]
) {
    float3 position = parameters.transform * float3(input.position, 1.0);
    return {
        float4(position.xy, 0.0, 1.0),
        input.color,
        parameters.textureOrigin
            + input.textureCoordinate * parameters.textureScale
    };
}

fragment float4 pixlFragment(
    VertexOutput input [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    sampler textureSampler [[sampler(0)]]
) {
    // Sampling preserves the texture's alpha representation. The selected
    // pipeline blend mode must expect straight or premultiplied fragment RGB.
    return texture.sample(textureSampler, input.textureCoordinate)
        * input.color;
}

struct SpriteVertexInput {
    float2 position [[attribute(0)]];
    float2 textureCoordinate [[attribute(2)]];
    float2 transformX [[attribute(3)]];
    float2 transformY [[attribute(4)]];
    float2 translation [[attribute(5)]];
    float2 textureOrigin [[attribute(6)]];
    float2 textureScale [[attribute(7)]];
    float4 tint [[attribute(8)]];
    uint modulationMode [[attribute(9)]];
};

struct SpriteVertexOutput {
    float4 position [[position]];
    float4 tint;
    float2 textureCoordinate;
    uint modulationMode [[flat]];
};

struct SpriteViewParameters {
    float3x3 projection;
};

vertex SpriteVertexOutput pixlSpriteVertex(
    SpriteVertexInput input [[stage_in]],
    constant SpriteViewParameters &view [[buffer(2)]]
) {
    float2 world = input.transformX * input.position.x
        + input.transformY * input.position.y
        + input.translation;
    float3 projected = view.projection * float3(world, 1.0);
    return {
        float4(projected.xy, 0.0, 1.0),
        input.tint,
        input.textureOrigin + input.textureCoordinate * input.textureScale,
        input.modulationMode
    };
}

fragment float4 pixlSpriteFragment(
    SpriteVertexOutput input [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    sampler textureSampler [[sampler(0)]]
) {
    float4 sampled = texture.sample(textureSampler, input.textureCoordinate);
    bool alphaMask = (input.modulationMode & 1u) != 0u;
    bool premultiplied = (input.modulationMode & 2u) != 0u;
    if (alphaMask) {
        float alpha = sampled.a * input.tint.a;
        return premultiplied
            ? float4(input.tint.rgb * alpha, alpha)
            : float4(input.tint.rgb, alpha);
    }
    float4 result = sampled * input.tint;
    if (premultiplied) result.rgb *= input.tint.a;
    return result;
}

struct ShapeVertexInput {
    float2 position [[attribute(0)]];
    float2 transformX [[attribute(3)]];
    float2 transformY [[attribute(4)]];
    float2 translation [[attribute(5)]];
    float4 parameters [[attribute(6)]];
    float4 fillColor [[attribute(7)]];
    float4 strokeColor [[attribute(8)]];
    float4 style [[attribute(9)]];
    float2 quadHalfExtent [[attribute(10)]];
};

struct ShapeVertexOutput {
    float4 position [[position]];
    float2 localPosition;
    float4 parameters [[flat]];
    float4 fillColor [[flat]];
    float4 strokeColor [[flat]];
    float4 style [[flat]];
};

vertex ShapeVertexOutput pixlShapeVertex(
    ShapeVertexInput input [[stage_in]],
    constant SpriteViewParameters &view [[buffer(2)]]
) {
    float2 world = input.transformX * input.position.x
        + input.transformY * input.position.y
        + input.translation;
    float3 projected = view.projection * float3(world, 1.0);
    return {
        float4(projected.xy, 0.0, 1.0),
        input.position * input.quadHalfExtent * 2.0,
        input.parameters,
        input.fillColor,
        input.strokeColor,
        input.style
    };
}

struct ExtendedShapeVertexInput {
    float2 position [[attribute(0)]];
    float2 transformX [[attribute(3)]];
    float2 transformY [[attribute(4)]];
    float2 translation [[attribute(5)]];
    float4 parameters [[attribute(6)]];
    float4 extendedParameters [[attribute(7)]];
    float4 fillColor [[attribute(8)]];
    float4 strokeColor [[attribute(9)]];
    float4 style [[attribute(10)]];
    float2 quadHalfExtent [[attribute(11)]];
};

struct ExtendedShapeVertexOutput {
    float4 position [[position]];
    float2 localPosition;
    float4 parameters [[flat]];
    float4 extendedParameters [[flat]];
    float4 fillColor [[flat]];
    float4 strokeColor [[flat]];
    float4 style [[flat]];
};

vertex ExtendedShapeVertexOutput pixlExtendedShapeVertex(
    ExtendedShapeVertexInput input [[stage_in]],
    constant SpriteViewParameters &view [[buffer(2)]]
) {
    float2 world = input.transformX * input.position.x
        + input.transformY * input.position.y
        + input.translation;
    float3 projected = view.projection * float3(world, 1.0);
    return {
        float4(projected.xy, 0.0, 1.0),
        input.position * input.quadHalfExtent * 2.0,
        input.parameters,
        input.extendedParameters,
        input.fillColor,
        input.strokeColor,
        input.style
    };
}

static float pixlRoundedBoxDistance(float2 point, float2 halfSize, float rounding) {
    float2 q = abs(point) - halfSize + rounding;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rounding;
}

static float pixlSegmentDistance(float2 p, float2 a, float2 b) {
    float2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

static float pixlRhombusDistance(float2 p, float2 b) {
    float2 q = abs(p);
    float h = clamp((-2.0 * dot(q, float2(b.x, -b.y)) + dot(b, float2(b.x, -b.y))) / dot(b, b), -1.0, 1.0);
    float d = length(q - 0.5 * b * float2(1.0 - h, 1.0 + h));
    return d * sign(q.x * b.y + q.y * b.x - b.x * b.y);
}

static float pixlTrapezoidDistance(float2 p, float r1, float r2, float he) {
    float2 k1 = float2(r2, he), k2 = float2(r2 - r1, 2.0 * he);
    p.x = abs(p.x);
    float2 ca = float2(p.x - min(p.x, p.y < 0.0 ? r1 : r2), abs(p.y) - he);
    float2 cb = p - k1 + k2 * clamp(dot(k1 - p, k2) / dot(k2, k2), 0.0, 1.0);
    return (cb.x < 0.0 && ca.y < 0.0 ? -1.0 : 1.0) * sqrt(min(dot(ca, ca), dot(cb, cb)));
}

static float pixlParallelogramDistance(float2 p, float wi, float he, float sk) {
    float2 e = float2(sk, he); p = p.y < 0.0 ? -p : p;
    float2 w = p - e; w.x -= clamp(w.x, -wi, wi);
    float2 d = float2(dot(w, w), -w.y);
    float s = p.x * e.y - p.y * e.x; p = s < 0.0 ? -p : p;
    float2 v = p - float2(wi, 0.0); v -= e * clamp(dot(v, e) / dot(e, e), -1.0, 1.0);
    d = min(d, float2(dot(v, v), wi * he - abs(s)));
    return sqrt(d.x) * sign(-d.y);
}

static float pixlEquilateralTriangleDistance(float2 p, float radius) {
    const float k = 1.7320508075688772;
    p.y += radius * 0.2886751346;
    p /= radius; p.x = abs(p.x) - 1.0; p.y += 1.0 / k;
    if (p.x + k * p.y > 0.0) p = float2(p.x - k * p.y, -k * p.x - p.y) * 0.5;
    p.x -= clamp(p.x, -2.0, 0.0);
    return -length(p) * sign(p.y) * radius;
}

static float pixlIsoscelesTriangleDistance(float2 p, float2 c) {
    p.y += c.y * 0.5;
    float2 q = float2(abs(p.x), p.y);
    float2 a = q - c * clamp(dot(q, c) / dot(c, c), 0.0, 1.0);
    float2 b = q - c * float2(clamp(q.x / c.x, 0.0, 1.0), 1.0);
    float s = -sign(c.y);
    float2 d = min(float2(dot(a,a), s * (q.x*c.y-q.y*c.x)), float2(dot(b,b), s*(q.y-c.y)));
    return -sqrt(d.x) * sign(d.y);
}

static float pixlUnevenCapsuleDistance(float2 p, float r1, float r2, float h) {
    p.y += (h + r2 - r1) * 0.5;
    float2 q = float2(abs(p.x), p.y); float b = (r1-r2)/h; float a = sqrt(1.0-b*b);
    float k = dot(q, float2(-b,a));
    if (k < 0.0) return length(q)-r1;
    if (k > a*h) return length(q-float2(0.0,h))-r2;
    return dot(q,float2(a,b))-r1;
}

static float pixlPentagonDistance(float2 p, float r) {
    const float3 k=float3(0.809016994,0.587785252,0.726542528); p=float2(abs(p.x),p.y);
    p-=2.0*min(dot(float2(-k.x,k.y),p),0.0)*float2(-k.x,k.y);
    p-=2.0*min(dot(float2(k.x,k.y),p),0.0)*float2(k.x,k.y);
    p-=float2(clamp(p.x,-r*k.z,r*k.z),r); return length(p)*sign(p.y);
}

static float pixlHexagonDistance(float2 p,float r){const float3 k=float3(-0.866025404,0.5,0.577350269);p=abs(p);p-=2.0*min(dot(k.xy,p),0.0)*k.xy;p-=float2(clamp(p.x,-k.z*r,k.z*r),r);return length(p)*sign(p.y);}
static float pixlOctagonDistance(float2 p,float r){const float3 k=float3(-0.9238795325,0.3826834323,0.4142135623);p=abs(p);p-=2.0*min(dot(k.xy,p),0.0)*k.xy;p-=2.0*min(dot(float2(-k.x,k.y),p),0.0)*float2(-k.x,k.y);p-=float2(clamp(p.x,-k.z*r,k.z*r),r);return length(p)*sign(p.y);}
static float pixlHexagramDistance(float2 p,float r){const float4 k=float4(-0.5,0.8660254038,0.5773502692,1.7320508076);p=abs(p);p-=2.0*min(dot(k.xy,p),0.0)*k.xy;p-=2.0*min(dot(k.yx,p),0.0)*k.yx;p-=float2(clamp(p.x,r*k.z,r*k.w),r);return length(p)*sign(p.y);}

static float pixlStarDistance(float2 p,float r,float n,float inner){float an=M_PI_F/n;float en=atan2(sin(an),cos(an)-inner);float2 acs=float2(cos(an),sin(an)),ecs=float2(cos(en),sin(en));float bn=fmod(atan2(abs(p.x),p.y),2.0*an)-an;p=length(p)*float2(cos(bn),abs(sin(bn)));p-=r*acs;p+=ecs*clamp(-dot(p,ecs),0.0,r*acs.y/ecs.y);return length(p)*sign(p.x);}

static float pixlPieDistance(float2 p,float r,float angle){float2 sc=float2(sin(angle),cos(angle));p=float2(abs(p.x),p.y);float l=length(p)-r;float m=length(p-sc*clamp(dot(p,sc),0.0,r));return max(l,m*sign(sc.y*p.x-sc.x*p.y));}

static float pixlVesicaDistance(float2 p,float r,float d){p=abs(p);float b=sqrt(r*r-d*d);return ((p.y-b)*d>p.x*b)?length(p-float2(0.0,b)):length(p-float2(-d,0.0))-r;}
static float pixlMoonDistance(float2 p,float d,float ra,float rb){p=float2(p.x,abs(p.y));float a=(ra*ra-rb*rb+d*d)/(2.0*d);float b=sqrt(max(ra*ra-a*a,0.0));if(d*(p.x*b-p.y*a)>d*d*max(b-p.y,0.0))return length(p-float2(a,b));return max(length(p)-ra,-(length(p-float2(d,0.0))-rb));}

static float pixlEggDistance(float2 p,float ra,float rb){const float k=1.7320508075688772;float r=ra-rb,top=k*r+rb;p.y+=(top-ra)*.5;p=float2(abs(p.x),p.y);return ((p.y<0.0)?length(p)-r:((k*(p.x+r)<p.y)?length(float2(p.x,p.y-k*r)):length(float2(p.x+r,p.y))-2.0*r))-rb;}
static float pixlHeartDistance(float2 p,float scale){p.y+=0.551776695*scale;p/=scale;p=float2(abs(p.x),p.y);if(p.x+p.y>1.0)return (length(p-float2(0.25,0.75))-0.3535533906)*scale;return sqrt(min(dot(p-float2(0.0,1.0),p-float2(0.0,1.0)),dot(p-0.5*max(p.x+p.y,0.0),p-0.5*max(p.x+p.y,0.0))))*sign(p.x-p.y)*scale;}
static float pixlCrossDistance(float2 p,float2 b){p=abs(p);if(p.y>p.x)p=p.yx;float2 q=p-b;float k=max(q.y,q.x);float2 w=k>0.0?q:float2(b.y-p.x,-k);return sign(k)*length(max(w,0.0));}
static float pixlRoundedXDistance(float2 p,float w,float r){p=abs(p);return length(p-min(p.x+p.y,w)*0.5)-r;}
static float pixlCubeRoot(float value){return sign(value)*pow(abs(value),1.0/3.0);}

static float pixlCutDiskDistance(float2 p,float r,float h){float w=sqrt(max(r*r-h*h,0.0));p.x=abs(p.x);float s=max((h-r)*p.x*p.x+w*w*(h+r-2.0*p.y),h*p.x-w*p.y);return s<0.0?length(p)-r:(p.x<w?h-p.y:length(p-float2(w,h)));}
static float pixlArcDistance(float2 p,float angle,float radius,float width){float2 sc=float2(sin(angle),cos(angle));p.x=abs(p.x);float k=sc.y*p.x>sc.x*p.y?dot(p,sc):length(p);return sqrt(max(dot(p,p)+radius*radius-2.0*radius*k,0.0))-width;}
static float pixlRingDistance(float2 p,float2 n,float radius,float width){p.x=abs(p.x);n=normalize(n);p=float2(n.x*p.x-n.y*p.y,n.y*p.x+n.x*p.y);return max(abs(length(p)-radius)-width,length(float2(p.x,max(0.0,abs(radius-p.y)-width)))*sign(p.x));}
static float pixlHorseshoeDistance(float2 p,float angle,float radius,float lengthValue,float width){float2 c=float2(cos(angle),sin(angle));p.x=abs(p.x);float l=length(p);p=float2(-c.x*p.x+c.y*p.y,c.y*p.x+c.x*p.y);p=float2((p.y>0.0||p.x>0.0)?p.x:l*sign(-c.x),p.x>0.0?p.y:l);p=float2(p.x-lengthValue,abs(p.y-radius)-width);return length(max(p,0.0))+min(0.0,max(p.x,p.y));}
static float pixlRoundedCrossDistance(float2 p,float h){float k=0.5*(h+1.0/h);p=abs(p);return p.x<1.0&&p.y<p.x*(k-h)+h?k-length(p-float2(1.0,k)):sqrt(min(dot(p-float2(0.0,h),p-float2(0.0,h)),dot(p-float2(1.0,0.0),p-float2(1.0,0.0))));}
static float pixlEllipseDistance(float2 p,float2 ab){float k0=length(p/ab),k1=length(p/(ab*ab));return k0*(k0-1.0)/max(k1,1e-6);}
static float pixlParabolaDistance(float2 pos,float k0,float2 halfSize){float direction=sign(k0);float k=abs(k0);pos=float2(abs(pos.x),pos.y*direction);float ik=1.0/k;float p=ik*(pos.y-0.5*ik)/3.0;float q=0.25*ik*ik*pos.x;float h=q*q-p*p*p;float r=sqrt(abs(h));float x=h>0.0?pixlCubeRoot(q+r)-pixlCubeRoot(r-q):2.0*cos(atan2(r,q)/3.0)*sqrt(max(p,0.0));float limit=min(halfSize.x,sqrt(max(halfSize.y/k,0.0)));x=clamp(x,0.0,limit);return length(pos-float2(x,k*x*x));}
static float pixlParabolaSegmentDistance(float2 pos,float wi,float he){pos.y+=he*.5;pos.x=abs(pos.x);float ik=wi*wi/he;float p=ik*(he-pos.y-0.5*ik)/3.0;float q=pos.x*ik*ik*0.25;float h=q*q-p*p*p;float r=sqrt(abs(h));float x=h>0.0?pixlCubeRoot(q+r)-pixlCubeRoot(r-q):2.0*cos(atan2(r,q)/3.0)*sqrt(max(p,0.0));x=min(x,wi);float curve=length(pos-float2(x,he-x*x/ik))*sign(ik*(pos.y-he)+pos.x*pos.x);return max(curve,-pos.y);}
static float pixlBlobbyCrossDistance(float2 pos,float he){pos*=2.0;pos=abs(pos);pos=float2(abs(pos.x-pos.y),1.0-pos.x-pos.y)*0.7071067811865476;float p=(he-pos.y-0.25/he)/(6.0*he);float q=pos.x/(he*he*16.0);float h=q*q-p*p*p;float x;if(h>0.0){float r=sqrt(h);x=pixlCubeRoot(q+r)-pixlCubeRoot(r-q);}else{x=2.0*sqrt(max(p,0.0))*cos(acos(clamp(q/(p*sqrt(max(p,1e-8))),-1.0,1.0))/3.0);}x=min(x,0.7071067811865476);float2 z=float2(x,he*(1.0-2.0*x*x))-pos;return length(z)*sign(z.y)*0.5;}
static float pixlTunnelDistance(float2 p,float2 wh){p.y+=(wh.x-wh.y)*.5;p=float2(abs(p.x),-p.y);float2 q=p-wh;float2 a=float2(max(q.x,0.0),q.y);float d1=dot(a,a);q.x=p.y>0.0?q.x:length(p)-wh.x;float2 b=float2(q.x,max(q.y,0.0));float d2=dot(b,b);float d=sqrt(min(d1,d2));return max(q.x,q.y)<0.0?-d:d;}
static float pixlStairsDistance(float2 p,float2 wh,float n){float2 ba=wh*n;float2 q=p+ba*.5;float d=min(pixlSegmentDistance(q,float2(0.0),float2(ba.x,0.0)),pixlSegmentDistance(q,float2(ba.x,0.0),ba));for(uint i=0;i<uint(n);++i){float2 hi=float2(ba.x-float(i)*wh.x,ba.y-float(i)*wh.y);float2 lo=hi-wh;d=min(d,pixlSegmentDistance(q,hi,float2(lo.x,hi.y)));d=min(d,pixlSegmentDistance(q,float2(lo.x,hi.y),lo));}float stepTop=ceil(clamp(q.x,0.0,ba.x)/wh.x)*wh.y;bool inside=q.x>=0.0&&q.x<=ba.x&&q.y>=0.0&&q.y<=stepTop;return inside?-d:d;}
static float pixlQuadraticCircleDistance(float2 p,float size){float a=size*.5;float2 q=abs(p);float t=clamp(atan2(q.y*q.y,q.x*q.x),1e-4,M_PI_F*.5-1e-4);for(uint i=0;i<5;++i){float c=cos(t),s=sin(t),rc=sqrt(c),rs=sqrt(s);float2 point=a*float2(rc,rs);float2 first=.5*a*float2(-s/rc,c/rs);float2 second=-.5*a*float2(rc+.5*s*s/(c*rc),rs+.5*c*c/(s*rs));float2 delta=point-q;float g=dot(delta,first);float gp=dot(first,first)+dot(delta,second);t=clamp(t-g/max(gp,1e-6),1e-4,M_PI_F*.5-1e-4);}float2 nearest=a*sqrt(float2(cos(t),sin(t)));float d=min(length(q-nearest),min(length(q-float2(a,0.0)),length(q-float2(0.0,a))));float2 q2=q*q;return d*sign(q2.x*q2.x+q2.y*q2.y-a*a*a*a);}
static float pixlHyperbolaDistance(float2 p,float scale,float2 halfSize){p=abs(p);float lo=scale/halfSize.y;float hi=halfSize.x;if(lo>hi)return 1e6;float x=clamp(max(p.x,sqrt(scale)),lo,hi);for(uint i=0;i<5;++i){float y=scale/x;float h=y-p.y;float x2=x*x;float g=(x-p.x)-scale*h/x2;float gp=1.0+(scale*scale)/(x2*x2)+2.0*scale*h/(x2*x);x=clamp(x-g/max(gp,1e-6),lo,hi);}return length(p-float2(x,scale/x));}
static float pixlQuadraticBezierDistance(float2 pos,float2 A,float2 B,float2 C);
static float pixlCoolSDistance(float2 p,float size){p/=size;float d0=pixlQuadraticBezierDistance(p,float2(.35,.5),float2(-.35,.5),float2(-.35,.25));float d1=pixlQuadraticBezierDistance(p,float2(-.35,.25),float2(-.35,0.),float2(0.));float d2=pixlQuadraticBezierDistance(p,float2(0.),float2(.35,0.),float2(.35,-.25));float d3=pixlQuadraticBezierDistance(p,float2(.35,-.25),float2(.35,-.5),float2(-.35,-.5));return min(min(d0,d1),min(d2,d3))*size;}
static float pixlCircleWaveDistance(float2 p,float radius,float width){float a=atan2(p.y,p.x);float wave=sin(a*6.0)*width*0.5;return abs(length(p)-(radius+wave))-width*0.5;}
static float pixlTriangleDistance(float2 p,float2 p0,float2 p1,float2 p2){float2 e0=p1-p0,e1=p2-p1,e2=p0-p2;float2 v0=p-p0,v1=p-p1,v2=p-p2;float2 q0=v0-e0*clamp(dot(v0,e0)/dot(e0,e0),0.0,1.0);float2 q1=v1-e1*clamp(dot(v1,e1)/dot(e1,e1),0.0,1.0);float2 q2=v2-e2*clamp(dot(v2,e2)/dot(e2,e2),0.0,1.0);float s=sign(e0.x*e2.y-e0.y*e2.x);float2 d=min(min(float2(dot(q0,q0),s*(v0.x*e0.y-v0.y*e0.x)),float2(dot(q1,q1),s*(v1.x*e1.y-v1.y*e1.x))),float2(dot(q2,q2),s*(v2.x*e2.y-v2.y*e2.x)));return -sqrt(d.x)*sign(d.y);}
static float pixlQuadraticBezierDistance(float2 pos,float2 A,float2 B,float2 C){float2 a=B-A,b=A-2.0*B+C,c=a*2.0,d=A-pos;float kk=1.0/dot(b,b);float kx=kk*dot(a,b);float ky=kk*(2.0*dot(a,a)+dot(d,b))/3.0;float kz=kk*dot(d,a);float p=ky-kx*kx,p3=p*p*p,q=kx*(2.0*kx*kx-3.0*ky)+kz,h=q*q+4.0*p3;float result;if(h>=0.0){h=sqrt(h);float2 x=(float2(h,-h)-q)*0.5;float2 uv=sign(x)*pow(abs(x),float2(1.0/3.0));float t=clamp(uv.x+uv.y-kx,0.0,1.0);float2 qos=d+(c+b*t)*t;result=dot(qos,qos);}else{float z=sqrt(-p);float v=acos(clamp(q/(p*z*2.0),-1.0,1.0))/3.0;float m=cos(v),n=sin(v)*1.7320508075688772;float3 t=clamp(float3(m+m,-n-m,n-m)*z-kx,0.0,1.0);float2 q0=d+(c+b*t.x)*t.x,q1=d+(c+b*t.y)*t.y,q2=d+(c+b*t.z)*t.z;result=min(dot(q0,q0),min(dot(q1,q1),dot(q2,q2)));}return sqrt(result);}

static float pixlCompactShapeDistance(uint kind,float2 p,float4 v){
    switch(kind){
        case 0:return length(p)-v.x;
        case 1:return pixlRoundedBoxDistance(p,v.xy,v.z);
        case 2:return pixlSegmentDistance(p,v.xy,v.zw);
        case 3:return pixlRhombusDistance(p,v.xy);
        case 4:return pixlTrapezoidDistance(p,v.x,v.y,v.z);
        case 5:return pixlParallelogramDistance(p,v.x,v.y,v.z);
        case 6:return pixlEquilateralTriangleDistance(p,v.x);
        case 7:return pixlIsoscelesTriangleDistance(p,v.xy);
        case 9:return pixlUnevenCapsuleDistance(p,v.x,v.y,v.z);
        case 10:return pixlPentagonDistance(p,v.x);
        case 11:return pixlHexagonDistance(p,v.x);
        case 12:return pixlOctagonDistance(p,v.x);
        case 13:return pixlHexagramDistance(p,v.x);
        case 14:return pixlStarDistance(p,v.x,v.y,v.z);
        case 15:return pixlPieDistance(p,v.x,v.y);
        case 16:return pixlCutDiskDistance(p,v.x,v.y);
        case 17:return pixlArcDistance(p,v.y,v.x,v.z);
        case 18:return pixlRingDistance(p,v.zw,v.x,v.y);
        case 19:return pixlHorseshoeDistance(p,v.y,v.x,v.z,v.w);
        case 20:return pixlVesicaDistance(p,v.x,v.y);
        case 21:return pixlMoonDistance(p,v.x,v.y,v.z);
        case 22:return pixlRoundedCrossDistance(p,v.x);
        case 23:return pixlEggDistance(p,v.x,v.y);
        case 24:return pixlHeartDistance(p,v.x);
        case 25:return pixlCrossDistance(p,v.xy);
        case 26:return pixlRoundedXDistance(p,v.x,v.y);
        case 27:return pixlEllipseDistance(p,v.xy);
        case 28:return pixlParabolaDistance(p,v.x,v.yz);
        case 29:return pixlParabolaSegmentDistance(p,v.x,v.y);
        case 31:return pixlBlobbyCrossDistance(p,v.x);
        case 32:return pixlTunnelDistance(p,v.xy);
        case 33:return pixlStairsDistance(p,v.xy,v.z);
        case 34:return pixlQuadraticCircleDistance(p,v.x);
        case 35:return pixlHyperbolaDistance(p,v.x,v.yz);
        case 36:return pixlCoolSDistance(p,v.x);
        case 37:return pixlCircleWaveDistance(p,v.x,v.y);
        default:return pixlRoundedBoxDistance(p,v.xy,v.z);
    }
}

static float2 pixlShapeCoverages(float distance,float width,float alignment,bool smooth) {
    float aa=max(fwidth(distance)*0.5,1e-5);
    float base=smooth?1.0-smoothstep(-aa,aa,distance):step(distance,0.0);
    if(width<=0.0)return float2(base,0.0);
    float outer=alignment<-.5?0.0:(alignment>.5?width:width*.5);
    float inner=alignment<-.5?-width:(alignment>.5?0.0:-width*.5);
    float total=smooth?1.0-smoothstep(outer-aa,outer+aa,distance):step(distance,outer);
    float fill=smooth?1.0-smoothstep(inner-aa,inner+aa,distance):step(distance,inner);
    return float2(fill,max(total-fill,0.0));
}

fragment float4 pixlShapeFragment(ShapeVertexOutput input [[stage_in]]) {
    uint kind = uint(input.style.x + 0.5);
    float distance = pixlCompactShapeDistance(kind,input.localPosition,input.parameters)-input.style.w;
    float width = input.style.y;
    bool smooth=input.style.z>2.0;
    float alignment=input.style.z-(smooth?4.0:0.0);
    float2 coverages=pixlShapeCoverages(distance,width,alignment,smooth);
    float fillCoverage=coverages.x,strokeCoverage=coverages.y;
    float4 fill = input.fillColor * fillCoverage;
    float4 stroke = input.strokeColor * strokeCoverage;
    return stroke + fill;
}

fragment float4 pixlGradientShapeFragment(
    ShapeVertexOutput input [[stage_in]],
    texture2d<float> atlas [[texture(1)]],
    sampler atlasSampler [[sampler(1)]]
) {
    uint packed = uint(input.style.x + 0.5);
    uint kind = packed & 63u;
    uint row = ((packed / 64u) & 255u) - 1u;
    uint placement = packed / 16384u;
    float distance = pixlCompactShapeDistance(kind,input.localPosition,input.parameters)-input.style.w;
    float width=input.style.y;
    bool smooth=input.style.z>2.0;float alignment=input.style.z-(smooth?4.0:0.0);float2 coverages=pixlShapeCoverages(distance,width,alignment,smooth);float fillCoverage=coverages.x,strokeCoverage=coverages.y;
    float2 start=input.fillColor.xy,end=input.fillColor.zw,delta=end-start;
    float t=placement==1u?length(input.localPosition-start)/input.fillColor.z:placement==2u?fract((atan2(input.localPosition.y-start.y,input.localPosition.x-start.x)-input.fillColor.z)/(2.0*M_PI_F)):dot(input.localPosition-start,delta)/dot(delta,delta);
    t=clamp(t,0.0,1.0);
    float y=(float(row)+.5)/float(atlas.get_height());
    float4 fill=atlas.sample(atlasSampler,float2(t,y))*fillCoverage;
    float4 stroke=input.strokeColor*strokeCoverage;
    return stroke+fill;
}

fragment float4 pixlExtendedShapeFragment(ExtendedShapeVertexOutput input [[stage_in]]) {
    uint kind = uint(input.style.x + 0.5);
    float distance = (kind == 8
        ? pixlTriangleDistance(input.localPosition,input.parameters.xy,input.parameters.zw,input.extendedParameters.xy)
        : pixlQuadraticBezierDistance(input.localPosition,input.parameters.xy,input.parameters.zw,input.extendedParameters.xy))-input.style.w;
    float width = input.style.y;
    bool smooth=input.style.z>2.0;float alignment=input.style.z-(smooth?4.0:0.0);float2 coverages=pixlShapeCoverages(distance,width,alignment,smooth);float fillCoverage=coverages.x,strokeCoverage=coverages.y;
    float4 fill=input.fillColor*fillCoverage,stroke=input.strokeColor*strokeCoverage;
    return stroke+fill;
}

fragment float4 pixlGradientExtendedShapeFragment(
    ExtendedShapeVertexOutput input [[stage_in]],
    texture2d<float> atlas [[texture(1)]],
    sampler atlasSampler [[sampler(1)]]
) {
    uint packed=uint(input.style.x+.5),kind=packed&63u,row=((packed/64u)&255u)-1u,placement=packed/16384u;
    float distance=(kind==8?pixlTriangleDistance(input.localPosition,input.parameters.xy,input.parameters.zw,input.extendedParameters.xy):pixlQuadraticBezierDistance(input.localPosition,input.parameters.xy,input.parameters.zw,input.extendedParameters.xy))-input.style.w;
    float width=input.style.y;
    bool smooth=input.style.z>2.0;float alignment=input.style.z-(smooth?4.0:0.0);float2 coverages=pixlShapeCoverages(distance,width,alignment,smooth);float fillCoverage=coverages.x,strokeCoverage=coverages.y;
    float2 start=input.fillColor.xy,end=input.fillColor.zw,delta=end-start;
    float t=placement==1u?length(input.localPosition-start)/input.fillColor.z:placement==2u?fract((atan2(input.localPosition.y-start.y,input.localPosition.x-start.x)-input.fillColor.z)/(2.0*M_PI_F)):dot(input.localPosition-start,delta)/dot(delta,delta);
    t=clamp(t,0.0,1.0);
    float y=(float(row)+.5)/float(atlas.get_height());
    float4 fill=atlas.sample(atlasSampler,float2(t,y))*fillCoverage;
    float4 stroke=input.strokeColor*strokeCoverage;
    return stroke+fill;
}

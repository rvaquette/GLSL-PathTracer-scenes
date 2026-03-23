const float Pi        = 3.1415;
const float OneOverPi = 1. / Pi;

//-- Math
float length2(vec3 v) {return dot(v,v);}

vec4 quaternion(float angle, vec3 axis)
{
    float halfAngle = angle / 2.;
    return vec4(axis.x * sin(halfAngle), axis.y * sin(halfAngle), axis.z * sin(halfAngle), cos(halfAngle));
}

// Based on GLM implementation
vec3 multiply(vec4 quat, vec3 p)
{
    vec3 quatVector = quat.xyz;
    vec3 uv         = cross(quatVector, p);
    vec3 uuv        = cross(quatVector, uv);

    return p + ((uv * quat.w) + uuv) * 2.;
}

vec4 conjugate(vec4 quat) { return vec4(-quat.x, -quat.y, -quat.z, quat.w); }

// Both n and ref must be normalized
vec4 toLocal(vec3 n, vec3 ref)
{
    if (dot(n, ref) < -1.f + 1e-4f)
        return vec4(1.f, 0.f, 0.f, 0.f);

    float angle = 1.f + dot(n, ref); // sqrt(length2(n) * length2(ref)) + dot( input, up );
    vec3  axis  = cross(n, ref);
    return normalize(vec4(axis, angle));
}

vec4 toLocalZ(vec3 n) { return toLocal(n, vec3(0., 0., 1.)); }

float getDiskArea(float radius) 
{
    return Pi * radius * radius;
}

float iorToReflectance(float ior)
{
    return ((ior - 1.) * (ior - 1.)) / ((ior + 1.) * (ior + 1.));
}

// Ref: https://en.wikipedia.org/wiki/Relative_luminance
float getLuminance(vec3 rgb)
{
    return rgb.x * 0.2126f + rgb.y * 0.7152f + rgb.z * 0.0722f;
}

//-- Sampling 

// Sampling Transformations Zoo
// Peter Shirley, Samuli Laine, David Hart, Matt Pharr, Petrik Clarberg,
// Eric Haines, Matthias Raab, and David Cline
// NVIDIA
vec3 sampleCosine(vec2 u)
{
    // 16.6.1 COSINE-WEIGHTED HEMISPHERE ORIENTED TO THE Z-AXIS
    float a = sqrt(u.x);
    float b = 2. * Pi * u.y;

    return vec3(a * cos(b), a * sin(b), sqrt(1.0f - u.x));
}

// Stratified Sampling of 2-Manifolds, Jim Arvo
// SIGGRAPH Course Notes 2001
// Found: https://twitter.com/keenanisalive/status/1529490555893428226?s=20&t=mxRju6YioMmlMOJ1fDVBpw
vec2 sampleCircle(vec2 u)
{
    float  r     = u.x;
    float  theta = u.y * 2. * Pi;
    return sqrt(r) * vec2(cos(theta), sin(theta));
}

vec3 sampleDisk(float height, float radius, vec2 u) 
{
    vec2 pd   = sampleCircle(u);
    return vec3(pd.x * radius, height, pd.y * radius);
}

// https://pbr-book.org/3ed-2018/Monte_Carlo_Integration/Importance_Sampling
float powerHeuristic(int nf, float fPdf, int ng, float gPdf)
{
    float f = float(nf) * fPdf, g = float(ng) * gPdf;
    return (f * f) / (f * f + g * g);
}

//-- Hashes

// https://www.shadertoy.com/view/Xt3cDn
// Modified from: iq's "Integer Hash - III" (https://www.shadertoy.com/view/4tXyWN)
uint baseHash(uvec3 p)
{
    p = 1103515245U*((p.xyz >> 1U)^(p.yzx));
    uint h32 = 1103515245U*((p.x^p.z)^(p.y>>3U));
    return h32^(h32 >> 16);
}
uint baseHash(uint p)
{
    p = 1103515245U*((p >> 1U)^(p));
    uint h32 = 1103515245U*((p)^(p>>3U));
    return h32^(h32 >> 16);
}
vec3 hash31(uint x)
{
    uint n = baseHash(x);
    uvec3 rz = uvec3(n, n*16807U, n*48271U); //see: http://random.mat.sbg.ac.at/results/karl/server/node4.html
    return vec3((rz >> 1) & uvec3(0x7fffffffU))/float(0x7fffffff);
}
float hash11(uint x)
{
    uint n = baseHash(x);
    return float(n)*(1.0/float(0xffffffffU));
}

// Reference: https://www.shadertoy.com/view/XlGcRh
// Hash Functions for GPU Rendering. Mark Jarzynski, & Marc Olano (2020).
// Journal of Computer Graphics Techniques (JCGT), 9(3), 20–38.
uvec4 pcg4d(uvec4 v)
{
    v = v * 1664525u + 1013904223u;

    v.x += v.y * v.w;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v.w += v.y * v.z;

    v ^= v >> 16u;

    v.x += v.y * v.w;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v.w += v.y * v.z;

    return v;
}

vec4 prng(inout uvec4 p)
{
    p.w++;
    return vec4(pcg4d(p)) * (1.0/float(0xffffffffu));
}

//-- Ray
struct Material
{
    vec3  baseColor;
    float roughness;
    float metallic;
    float ior;
    float specularTransmission;
    float specularTint;
    vec3  transmittance;
    float atDistance;
    float clearcoat;
    float clearcoatGloss;

    // TODO list
    float anisotropic;
};

Material defaultMaterial() {
    Material material;
    material.baseColor            = vec3(1., 0., 1.);
    material.metallic             = 1.;
    material.ior                  = 1.52;
    material.roughness            = 0.;
    material.specularTransmission = 0.;
    material.transmittance        = vec3(1.);
    material.atDistance           = 1.;
    material.specularTint         = 1.;
    material.clearcoatGloss       = 0.;
    material.clearcoat            = 0.;
    

    return material;
}

struct HitInfo
{
    float    t;
    vec3     normal;
    Material material;
};

HitInfo defaultHitInfo() {
    return HitInfo(-1., vec3(0.), defaultMaterial());
}

struct LightSample {
    vec3  wi;
    vec3 intensity;
    float pdf;
};

// A Fast and Robust Method for Avoiding Self-Intersection, Carsten Wächter and Nikolaus Binder, NVIDIA
// Reference: https://github.com/Apress/ray-tracing-gems/blob/master/Ch_06_A_Fast_and_Robust_Method_for_Avoiding_Self-Intersection/offset_ray.cu
vec3 offsetRay(vec3 p, vec3 n)
{
    const float origin      = 1.0f / 32.0f;
    const float float_scale = 1.0f / 65536.0f;
    const float int_scale   = 256.0f;

    ivec3 of_i = ivec3(int_scale * n.x, int_scale * n.y, int_scale * n.z);

    vec3 p_i = vec3(intBitsToFloat(floatBitsToInt(p.x) + ((p.x < 0.) ? -of_i.x : of_i.x)),
                    intBitsToFloat(floatBitsToInt(p.y) + ((p.y < 0.) ? -of_i.y : of_i.y)),
                    intBitsToFloat(floatBitsToInt(p.z) + ((p.z < 0.) ? -of_i.z : of_i.z)));

    return vec3(abs(p.x) < origin ? p.x + float_scale * n.x : p_i.x,
                abs(p.y) < origin ? p.y + float_scale * n.y : p_i.y,
                abs(p.z) < origin ? p.z + float_scale * n.z : p_i.z);
}

// https://iquilezles.org/articles/intersectors/
vec2 iSphere( in vec3 ro, in vec3 rd, in vec3 c, float r )
{
    float d = length( c - ro );
	float a = 0.f;
	if ( d > r )
		a = d - r;
	ro += rd * a;

	vec3 po = ro - c;
	float proj = dot(rd, po);

	float delta = proj * proj - (dot(po, po) - r * r);
	if ( delta < 0.f )
        return vec2(-1.);
    
    float sqrd = sqrt( delta );
    return vec2(-proj - sqrd, -proj + sqrd) + a;
}
float iDisk(in vec3 ro, in vec3 rd, vec3 c, vec3 n, float r ) {
    vec3  o = ro - c;
    float t = -dot(n,o)/dot(rd,n);
    vec3  q = o + rd*t;
    return (dot(q,q)<r*r) ? t : -1.0;
}
vec2 iBox( in vec3 ro, in vec3 rd, vec3 boxSize, out vec3 outNormal ) 
{
    vec3 m = 1.0/rd; // can precompute if traversing a set of aligned boxes
    vec3 n = m*ro;   // can precompute if traversing a set of aligned boxes
    vec3 k = abs(m)*boxSize;
    vec3 t1 = -n - k;
    vec3 t2 = -n + k;
    float tN = max( max( t1.x, t1.y ), t1.z );
    float tF = min( min( t2.x, t2.y ), t2.z );
    if( tN>tF || tF<0.0) return vec2(-1.0); // no intersection
    outNormal = (tN>0.0) ? step(vec3(tN),t1) : // ro ouside the box
                           step(t2,vec3(tF));  // ro inside the box
    outNormal *= -sign(rd);
    return vec2( tN, tF );
}

// Materials

vec3 schlickFresnel(vec3 f0, float cosThetaD) 
{
    return f0 + (1. - f0) * pow(1. - cosThetaD, 5.);
}

// Found: https://github.com/boksajak/brdf/blob/master/brdf.h#L710
float getSmithG1GGX(float sn2, float alpha2) {
	return 2. / (sqrt(((alpha2 * (1. - sn2)) + sn2) / sn2) + 1.);
}

// Moving Frostbite to Physically Based Rendering by Lagarde & de Rousiers
// Found: https://github.com/boksajak/brdf/blob/master/brdf.h#L653
// Includes specular BRDF denominator
float getSmithG2GGX(float won, float win, float alpha2) 
{
    float ggxv = win * sqrt(won * won * (1. - alpha2) + alpha2);
    float ggxl = won * sqrt(win * win * (1. - alpha2) + alpha2);
    
    return 0.5 / (ggxv + ggxl);
}

// Found: https://github.com/boksajak/brdf/blob/master/brdf.h#L710
float getDGGX(float hn, float alpha2) 
{
    float b = ((alpha2 - 1.) * hn * hn + 1.);
	return alpha2 / max(1e-4, Pi * b * b);
}

// Eric Heitz, A Simpler and Exact Sampling Routine for the GGX Distribution of Visible Normals, 
// Technical report 2017
vec3 sampleGGXVNDF(vec3 V_, float alpha_x, float alpha_y, float U1, float U2)
{
    // stretch view
    vec3 V = normalize(vec3(alpha_x * V_.x, alpha_y * V_.y, V_.z));
    
    // orthonormal basis
    vec3 T1 = (V.z < 0.9999) ? normalize(cross(V, vec3(0,0,1))) : vec3(1,0,0);
    vec3 T2 = cross(T1, V);
    
    // sample point with polar coordinates (r, phi)
    float a = 1.0 / (1.0 + V.z);
    float r = sqrt(U1);
    float phi = (U2<a) ? U2/a * Pi : Pi + (U2-a)/(1.0-a) * Pi;
    float P1 = r*cos(phi);
    float P2 = r*sin(phi)*((U2<a) ? 1.0 : V.z);
    
    // compute normal
    vec3 N = P1*T1 + P2*T2 + sqrt(max(0.0, 1.0 - P1*P1 - P2*P2))*V;
    
    // unstretch
    N = normalize(vec3(alpha_x*N.x, alpha_y*N.y, max(0.0, N.z)));
    return N;
}

// Sampling Visible GGX Normals with Spherical Caps, Dupuy & Benyoub
// https://arxiv.org/pdf/2306.05044.pdf
// Sampling the visible hemisphere as half vectors (our method)
vec3 SampleVndf_Hemisphere(vec2 u, vec3 wi)
{
    // sample a spherical cap in (-wi.z, 1]
    float phi = 2.0f * Pi * u.x;
    float z = (1.0f - u.y) * (1.0f + wi.z) - wi.z;
    float sinTheta = sqrt(clamp(1.0f - z * z, 0.0f, 1.0f));
    float x = sinTheta * cos(phi);
    float y = sinTheta * sin(phi);
    vec3 c = vec3(x, y, z);
    // compute halfway direction;
    vec3 h = c + wi;
    // return without normalization (as this is done later)
    return h;
}

#if 0
vec3 SampleVndf_GGX(vec2 u, vec3 wi, vec2 alpha)
{
    // warp to the hemisphere configuration
    vec3 wiStd = normalize(vec3(wi.xy * alpha, wi.z));
    // sample the hemisphere (see implementation 2 or 3)
    vec3 wmStd = SampleVndf_Hemisphere(u, wiStd);
    // warp back to the ellipsoid configuration
    vec3 wm = normalize(vec3(wmStd.xy * alpha, wi.z));
    // return final normal
    return wm;
}
#else 
vec3 SampleVndf_GGX(vec2 u, vec3 wi, vec2 alpha){
    return sampleGGXVNDF(wi, alpha.x, alpha.y, u.x, u.y);
}
#endif 

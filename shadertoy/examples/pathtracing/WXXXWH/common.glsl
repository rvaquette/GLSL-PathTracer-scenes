/*
    GGX VNDF - Multiple scattering using random walk algorithm

    Author:
        @LVutner

    Credits: 
        @Stubman - Raycast logic
        @selfshadow - GGX heightfield function

    Info:
        Very simple example of multiple scattered GGX material.
        Based on "Multiple-Scattering Microfacet BSDFs with the Smith Model"

    References:
        [R. Cook & K. Torrance, 1982] "A Reflectance Model for Computer Graphics"
        [B. Walter et al, 2007] "Microfacet Models for Refraction through Rough Surfaces"
        [E. Heitz, 2014] "Understanding the Masking-Shadowing Function in Microfacet-based BRDFs"  
        [E. Heitz, 2018] "Sampling the GGX Distribution of Visible Normals"
        [E. Heitz & J. Dupuy, 2015] "Implementing a Simple Anisotropic Rough Diffuse Material with Stochastic Evaluation"
        [E. Heitz, 2016] "Multiple-Scattering Microfacet BSDFs with the Smith Model"
        [J. Dupuy & A. Benyoub, 2023] "Sampling Visible GGX Normals with Spherical Caps"
*/

//////////////////////////////////////////////////////////////////////////////
//Settings
//////////////////////////////////////////////////////////////////////////////

//Quality settings
#define IS_SAMPLE_COUNT 8 //Sample count

//Raycast settings
#define MAX_DISTANCE 200.0 //Max distance of primary ray

//Hardcoded values
#define PI float(3.141592)

//////////////////////////////////////////////////////////////////////////////
//BRDF UTILS
//////////////////////////////////////////////////////////////////////////////

//Fresnel approximation using spherical gaussians
float F_SphericalGaussian(float dotproduct, float F0)
{
    return F0 + (1.0 - F0) * exp2((-5.55473 * dotproduct - 6.98316) * dotproduct);
}

//GGX heightfield
float sample_ggx_height(float Xi, vec3 direction, float height, float alpha)
{
    float direction_length = length(vec3(direction.xy * alpha, 1.0));
    float delta = -log(1.0f - Xi) * direction.z / max(0.5 * (direction_length - direction.z), 1e-6);

    return height + delta;
}

//Returns microfacet visible normal with GGX distribution
vec3 sample_ggx_vndf(vec3 V_tangent, vec2 Xi, float alpha)
{
	//stretch the view direction
    vec3 V_tangent_stretched = normalize(vec3(V_tangent.xy * alpha, V_tangent.z));

	//sample a spherical cap in (-wi.z, 1]
    float phi = PI * 2.0 * Xi.x;
    
	vec3 hemisphere = vec3(cos(phi), sin(phi), 0.0);

	//normalize (z)
	hemisphere.z = (1.0 - Xi.y) * (1.0 + V_tangent_stretched.z) + -V_tangent_stretched.z;	

	//normalize (hemi * sin theta)
	hemisphere.xy *= sqrt(clamp(1.0 - hemisphere.z * hemisphere.z, 0.0, 1.0));

	//halfway direction
	hemisphere += V_tangent_stretched;

	//unstretch and normalize
	return normalize(vec3(hemisphere.xy * alpha, hemisphere.z));
}

//Returns cosine weighted hemisphere oriented on N
vec3 sample_cosine_hemisphere(vec3 N, vec2 Xi)
{
    float phi = 2.0 * PI * Xi.x;
    Xi.y = Xi.y * 2.0 - 1.0;

    vec3 sphere = vec3(0.0);
	sphere.x = cos(phi) * sqrt(1.0 - Xi.y * Xi.y);
	sphere.y = sin(phi) * sqrt(1.0 - Xi.y * Xi.y);
	sphere.z = Xi.y;
 
    return normalize(N + sphere);
}

//////////////////////////////////////////////////////////////////////////////
//IMAGE
//////////////////////////////////////////////////////////////////////////////

//sRGB to linear
vec3 toLinear(vec3 sRGB)
{
    bvec3 cutoff = lessThan(sRGB, vec3(0.04045));
    vec3 higher = pow((sRGB + vec3(0.055)) / vec3(1.055), vec3(2.4));
    vec3 lower = sRGB / vec3(12.92);

    return mix(higher, lower, cutoff);
}

//Linear to sRGB
vec3 fromLinear(vec3 linearRGB)
{
    bvec3 cutoff = lessThan(linearRGB, vec3(0.0031308));
    vec3 higher = vec3(1.055) * pow(linearRGB, vec3(1.0 / 2.4)) - vec3(0.055);
    vec3 lower = linearRGB * vec3(12.92);

    return mix(higher, lower, cutoff);
}

const mat3 ACESInputMat = mat3(
    0.59719, 0.35458, 0.04823,
    0.07600, 0.90834, 0.01566,
    0.02840, 0.13383, 0.83777
);

const mat3 ACESOutputMat = mat3(
     1.60475, -0.53108, -0.07367,
    -0.10208,  1.10813, -0.00605,
    -0.00327, -0.07276,  1.07602
);

vec3 RRTAndODTFit(vec3 v) 
{
    vec3 a = v * (v + 0.0245786);
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return a / b;
}

//////////////////////////////////////////////////////////////////////////////
//RAYCAST
//////////////////////////////////////////////////////////////////////////////


struct RayDesc
{
    vec3 Origin; //Ray origin
    vec3 Direction; //Ray direction
    float TMin; //Minimal distance
    float TMax; //Max distance
};

struct Material
{
    vec3 albedo; //Albedo
    float alpha; //GGX alpha
};

struct HitInfo
{
    vec3 position; //Position
    vec3 normal; //Normal
    float dist; //Traveled distance    
    Material material; //Materials
};


void ray_sphere_intersection(RayDesc ray, vec4 sphere, Material mat, inout HitInfo hit)
{
    //from iq...
	vec3 position = ray.Origin - sphere.xyz;
	float b = dot(position, ray.Direction);
	float c = dot(position, position) - sphere.w * sphere.w;
	float h = b * b - c;

    float dist = h < 0.0 ? -1.0 : -b - sqrt(h);

    if(dist > 0.0)
    {
        hit.dist = dist;
        hit.position = ray.Origin + ray.Direction * hit.dist;
        hit.normal = (hit.position - sphere.xyz) / sphere.w;
        hit.material = mat;
    }
    else
        hit.dist = -1.0;
}


//Creates materials for metallic-roughness workflow
Material remap_materials(vec3 albedo, float roughness)
{
    Material o;

    o.albedo = albedo;

    //GGX alpha  
    o.alpha = clamp(roughness * roughness, 1.0 / 255.0, 1.0);

    //Output
    return o;
}

HitInfo overrideHit(HitInfo a, HitInfo b) 
{ 
    if (a.dist < b.dist) 
        return a; 
    else 
        return b; 
}

////////////////////////////////////////////////
//RNG
////////////////////////////////////////////////

uint triple32(uint x) 
{
	// https://nullprogram.com/blog/2018/07/31/
	x ^= x >> 17;
	x *= 0xed5ad4bbu;
	x ^= x >> 11;
	x *= 0xac4c1b51u;
	x ^= x >> 15;
	x *= 0x31848babu;
	x ^= x >> 14;
	return x;
}

uint randState;

void InitRand(uint seed) 
{ 
    randState = triple32(seed); 
}

uint RandNext() 
{ 
    return randState = triple32(randState); 
}

#define RandNextF() (float(RandNext()) / float(0xffffffffu))
#define RandNext2() uvec2(RandNext(), RandNext())
#define RandNext2F() (vec2(RandNext2()) / float(0xffffffffu))

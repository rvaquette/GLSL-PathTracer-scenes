/** 
 * Created by Steven Sell (ssell) / 2017
 * License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
 */

//------------------------------------------------------------------------------------------
// Defines to see individual lighting elements
//------------------------------------------------------------------------------------------

//#define DIFFUSE_ONLY
//#define SPECULAR_ONLY
//#define SPECULAR_NDF_ONLY
//#define SPECULAR_ATTEN_ONLY
//#define SPECULAR_FRESNEL_ONLY

/*
 * -----------
 * - Sources -
 * -----------
 * 
 *   Real Shading in Unreal Engine 4
 *   http://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf
 *
 *   Physically Based Rendering - Cook–Torrance
 *   http://www.codinglabs.net/article_physically_based_rendering_cook_torrance.aspx
 * 
 *   PBR Theory
 *   https://learnopengl.com/#!PBR/Theory
 *
 * -----------------
 * - Channel Input -
 * -----------------
 *
 *   iChannel0: UI Input/Render (from Buf A)
 *   iChannel1: Roughness Texture
 *   iChannel2: Albedo Texture
 *   iChannel3: Ambient IBL Cubemap
 *
 * -----------
 * - Sliders -
 * -----------
 *
 *   Roughness: [0.0, 1.0] Controls the microfacet intensity. Higher roughness results
 *   in the specular lighting being spread across a great part of the surface. Low roughness
 *   results in a smoother surface and more focused/tight specular highlights.
 *
 *   Metallic: [0.0, 1.0] Controls the incident fresnel term. Performs a mix(0.04, 1.0, ).
 *   Insulators (dielectrics) such as organics, plastic, stone, etc. have a (much) lower
 *   incident fresnel value, and thus a lower metallic value. Conductors such as metals have
 *   a higher incident fresnel term and thus a higher metallic value. The final fresnel value
 *   also controls the ratio between (diffuse:specular) lighting, and thus a lower metallic
 *   value results in a greater diffuse (and smaller specular) contribution.
 *
 *   DirectIntens: [0.0, 4.0] Controls an intensity modifier applied to the direct lighting
 *   (the directional light source). 
 *
 *   AmbientIntens: [0.0, 4.0] Controls an intensity modifier applied to the ambient lighting
 *   (the environmental map reflection).
 *
 *   Rough: [Flat, Texture] If flat, the value specified in 'Roughness' will be used as the
 *   roughness parameter in lighting calculations. If 'Texture', then the roughness parameter
 *   is calculated as (texture(iChannel1).r * Roughness).
 *
 *   Diff: [Normals, Texture] If 'Normals', then adjusted surface normals will be used as the
 *   albedo color. Otherwise, the texture in iChannel2 will be sampled.
 *
 *   IBL Steps: [1.0, 128.0] Number of steps used to calculate the IBL (Image-Based Lighting)
 *   ambient light value. Turn both Roughness and Metallic up and see the benefit of a large 
 *   number of IBL steps.
 *
 *   HDR On: [Off, On] Enables/disables the HDR.
 *
 * -----------------
 * - Lighting Flow -
 * -----------------
 *
 * *(In Progress)*
 *
 * This section will give a high-level overview of the lighting calculations
 * and the order in which they occur. This should help provide a basic idea
 * of how the various functions interact with each other.
 *
 * Before I begin, there are two things to note:
 *
 *     (1) The individual functions have more detailed/specific comments.
 *     (2) The cited references above cover this topic much better than me.
 *
 * Now, to begin, the general equation for PBR lighting is:
 *
 *     light = (kD * diffuse) + (kS * specular)
 *
 * Where kD:kS represent the ratio between diffuse and specular lighting. 
 * Due to the pesky law called the Conservation of Energy, our outgoing 
 * light can not exceed our incoming light and thus (kD + kS) == 1.0.
 *
 *   --------------------
 *   - Diffuse Lighting -
 *   --------------------
 *
 *   Diffuse light is the light that is refracted: enters the body of the substance,
 *   scatters internally, and then eventually exits the substance. Along the way some
 *   of the light is absorbed and transformed into heat.
 *
 *   The extent to which the light scatters, and the randomness of it, allows it to be
 *   approximated as being equal from all angles. And thus the diffuse term does not
 *   vary as the viewing angle changes.
 *
 *   This shader calculates the diffuse term using the simple Lambertian function of:
 *
 *       diffuse = (albedo / pi)
 *       albedo = sample of texture in iChannel2
 *
 *   There are other more accurate and complex diffuse calculations, but the Lambertian
 *   is relatively accurate and, most importantly, extremely cheap.
 *
 *   The ratio of diffuse lighting is calculated as:
 *
 *       kD = (1.0 - kS)
 *
 *   Where kS is detailed later.
 *
 *   -----------------------------
 *   - Specular Lighting General -
 *   -----------------------------
 *
 *   The specular lighting component is split into two different variations:
 *
 *       (1) Analytical
 *       (2) Image-Based Lighting (IBL)
 *
 *   The scene in this shader makes use of one of each.
 *
 *   In general, specular lighting is the light that is reflected off of the
 *   surface and does not enter into the body. As it does not enter the body,
 *   it does not get absorbed or take on the albedo color. 
 *
 *   Also, unlike the diffuse component, it is based on view angle in addition
 *   to the surface normal and light direction.
 *
 *   Specular light is composed of three distinct parts: normal distribution function (NDF),
 *   geometric attenuation, and fresnel reflectivity.
 *
 *   These combined create the Bidirectional Reflectance Distribution Function (BRDF).
 *
 *   For both modes of specular lighting, kS is equal to the Fresnel reflectance.
 *   
 *   --------------
 *   - Analytical -
 *   --------------
 *
 *   The single directional light in the scene makes use of analytical specular lighting.
 *   The formula for analytical lighting is:
 *
 *       = (NDF * Fresnel * Attenuation) / (4.0 * dot(normal, toLight) * dot(normal, toView))
 *
 *   ------------------------
 *   - Image-Based Lighting -
 *   ------------------------
 * 
 *   For ambient lighting we make use of an environmental map.
 *
 *   A hemispherical integration is approximated using a Riemann Sum. For each step
 *   of the sum, a light vector to the environmental map is sampled. These sample directions
 *   are generated using the Hammersley distribution, and are averaged for the total
 *   ambient contribution.
 */

#define Epsilon         0.001
#define NearClip        Epsilon
#define FarClip         20.0

#define PI              3.14159
#define ONE_OVER_PI     0.31831
#define ONE_OVER_TWO_PI 0.15915

float Roughness         = 0.0;
float Metallic          = 0.0;
float DirectIntensity   = 1.0;
float AmbientIntensity  = 1.0;

float RoughTextureOn    = 1.0;
float AlbedoTextureOn   = 1.0;
float IBLSteps          = 1.0;

//------------------------------------------------------------------------------------------
// Math Functions
//------------------------------------------------------------------------------------------

// if(a > b) { return ra; } else { return rb; }
float StepValue1(float a, float b, float ra, float rb)
{
    float s = step(a, b);
    return (ra * abs(s - 1.0)) + (rb * s);
}

vec3 StepValue3(float a, float b, vec3 ra, vec3 rb)
{
    float s = step(a, b);
    return (ra * abs(s - 1.0)) + (rb * s);
}

//------------------------------------------------------------------------------------------
// UI Functions
//------------------------------------------------------------------------------------------

float UISlider(int id)
{
    return texture(iChannel0, vec2(float(id) + 0.5, 0.5) / iResolution.xy).r;
}

vec4 RenderSliders(in vec2 uv)
{
    Roughness        = clamp(UISlider(0), 0.001, 1.0);
    Metallic         = clamp(UISlider(1), 0.0, 1.0);
    DirectIntensity  = clamp(UISlider(2), 0.0, 1.0) * 4.0;
    AmbientIntensity = clamp(UISlider(3), 0.0, 1.0) * 4.0;
    
    RoughTextureOn   = clamp(UISlider(4), 0.0, 1.0);
    AlbedoTextureOn  = clamp(UISlider(5), 0.0, 1.0);
    IBLSteps         = 1.0 + clamp(UISlider(6), 0.0, 1.0) * 64.0;
    
    return texture(iChannel0, uv);
}

//------------------------------------------------------------------------------------------
// Ray Structures and Functions
//------------------------------------------------------------------------------------------
    
struct Ray
{
	vec3 origin;
    vec3 direction;
};
    
struct RayHit
{
    bool  hit;
  	vec3  surfPos;
    vec3  surfNorm;
    float material;
};
    
//------------------------------------------------------------------------------------------
// Camera Structures and Functions
//------------------------------------------------------------------------------------------

struct Camera
{
    vec3 right;
    vec3 up;
    vec3 forward;
    vec3 origin;
};

Ray Camera_GetRay(in Camera camera, vec2 uv)
{
    Ray ray;
    
    uv    = (uv * 2.0) - 1.0;
    uv.x *= (iResolution.x / iResolution.y);
    
    ray.origin    = camera.origin;
    ray.direction = normalize((uv.x * camera.right) + (uv.y * camera.up) + (camera.forward * 2.5));

    return ray;
}

Camera Camera_LookAt(vec3 origin, vec3 lookAt)
{
	Camera camera;
    
    camera.origin  = origin;
    camera.forward = normalize(lookAt - camera.origin);
    camera.right   = normalize(cross(camera.forward, vec3(0.0, 1.0, 0.0)));
    camera.up      = normalize(cross(camera.right, camera.forward));
    
    return camera;
}

//------------------------------------------------------------------------------------------
// SDF Functions
//------------------------------------------------------------------------------------------

float Scene_SDF(vec3 point, inout RayHit hit)
{
  	float sdf = FarClip;
    
    float circle = length(abs(point - vec3(0.0, 0.0, 0.0))) - 1.0;
    hit.material = StepValue1(sdf, circle, 1.0, hit.material); 
    sdf = min(sdf, circle);
    
    return circle;
}

vec3 Scene_Normal(vec3 point)
{
    RayHit hit;

	return normalize(vec3(
        (Scene_SDF(vec3(point.x + Epsilon, point.y, point.z), hit) - Scene_SDF(vec3(point.x - Epsilon, point.y, point.z), hit)),
        (Scene_SDF(vec3(point.x, point.y + Epsilon, point.z), hit) - Scene_SDF(vec3(point.x, point.y - Epsilon, point.z), hit)),
        (Scene_SDF(vec3(point.x, point.y, point.z + Epsilon), hit) - Scene_SDF(vec3(point.x, point.y, point.z - Epsilon), hit))));
}

//------------------------------------------------------------------------------------------
// Raymarching
//------------------------------------------------------------------------------------------

RayHit RaymarchScene(in Ray ray)
{
    RayHit hit;
    
    hit.hit      = false;
    hit.material = 0.0;
    
    float sdf = FarClip;
    
    for(float depth = NearClip; depth < FarClip; )
    {
    	vec3 pos = ray.origin + (ray.direction * depth);
        
        sdf = Scene_SDF(pos, hit);
        
        if(sdf < Epsilon)
        {
            hit.hit      = true;
            hit.surfPos  = pos;
            hit.surfNorm = Scene_Normal(pos);
            
            return hit;
        }
        
        depth += sdf;
    }
    
    return hit;
}

//------------------------------------------------------------------------------------------
// Texture Sampling
//------------------------------------------------------------------------------------------

// Source: https://www.shadertoy.com/view/ld3SRr
vec4 SampleSphere(vec3 p, vec3 n, sampler2D sampler)
{
    p = fract(p * 0.5 +0.5);
    
    float sw = 0.1;
    vec3 stitchingFade = vec3(1.)-smoothstep(vec3(0.5-sw),vec3(0.5),abs(p-0.5));
    
    float fTotal = abs(n.x)+abs(n.y)+abs(n.z);
    vec4 cX = abs(n.x)*texture(sampler,p.zy);
    vec4 cY = abs(n.y)*texture(sampler,p.xz);
    vec4 cZ = abs(n.z)*texture(sampler,p.xy);
    
    return  vec4(stitchingFade.y*stitchingFade.z*cX.rgb
                +stitchingFade.x*stitchingFade.z*cY.rgb
                +stitchingFade.x*stitchingFade.y*cZ.rgb,cX.a+cY.a+cZ.a)/fTotal;
}

float SampleRoughness(in vec3 p, in vec3 n)
{
    return SampleSphere(p, n, iChannel1).r;
}

vec3 SampleAlbedo(in vec3 p, in vec3 n)
{
    return SampleSphere(p, n, iChannel2).rgb;
}

vec3 SampleEnvironment(in vec3 reflVec)
{
    return texture(iChannel3, reflVec).rgb;
}

//------------------------------------------------------------------------------------------
// Light Structures and Functions
//------------------------------------------------------------------------------------------

/**
 * Calculates the vector (h) half-way inbetween the light (l) and view (v).
 *
 *       v\   |h  /l
 *         \  |  /
 *          \ | /
 *           \|/
 * -------------------------
 */
vec3 CalculateHalfVector(
    in vec3 toLight,
    in vec3 toView)
{
    return normalize(toLight + toView);
}

/**
 * GGX/Trowbridge-Reitz NDF
 *
 * Calculates the specular highlighting from surface roughness.
 *
 * Roughness lies on the range [0.0, 1.0], with lower values
 * producing a smoother, "glossier", surface. Higher values 
 * produce a rougher surface with the specular lighting distributed
 * over a larger surface area.
 *
 * See it graphed at:
 * https://www.desmos.com/calculator/pjzk3yafzs
 */
float CalculateNDF(
    in vec3  surfNorm,
    in vec3  halfVector,
    in float roughness)
{
    float a = (roughness * roughness);
    float halfAngle = dot(surfNorm, halfVector);
    
    return (a / (PI * pow((pow(halfAngle, 2.0) * (a - 1.0) + 1.0), 2.0)));
}

/**
 * GGX/Schlick-Beckmann microfacet geometric attenuation.
 *
 * The attenuation is modified by the roughness (input as k)
 * and approximates the influence/amount of microfacets in the surface.
 * A microfacet is a sub-pixel structure that affects light
 * reflection/occlusion.
 */
float CalculateAttenuation(
    in vec3  surfNorm,
    in vec3  vector,
    in float k)
{
    float d = max(dot(surfNorm, vector), 0.0);
 	return (d / ((d * (1.0 - k)) + k));
}

/**
 * GGX/Schlick-Beckmann attenuation for analytical light sources.
 */
float CalculateAttenuationAnalytical(
    in vec3  surfNorm,
    in vec3  toLight,
    in vec3  toView,
    in float roughness)
{
    float k = pow((roughness + 1.0), 2.0) * 0.125;
    
    float lightAtten = CalculateAttenuation(surfNorm, toLight, k);
    float viewAtten  = CalculateAttenuation(surfNorm, toView, k);
    
    return (lightAtten * viewAtten);
}

/**
 * GGX/Schlick-Beckmann attenuation for IBL light sources.
 * Uses Disney modification of k to reduce hotness.
 */
float CalculateAttenuationIBL(
    in float roughness,
    in float normDotLight,          // Clamped to [0.0, 1.0]
    in float normDotView)           // Clamped to [0.0, 1.0]
{
    float k = pow(roughness, 2.0) * 0.5;
    
    float lightAtten = (normDotLight / ((normDotLight * (1.0 - k)) + k));
    float viewAtten  = (normDotView / ((normDotView * (1.0 - k)) + k));
    
    return (lightAtten * viewAtten);
}

/**
 * Calculates the Fresnel reflectivity.
 * The metalic parameter controls the fresnel incident value (fresnel0).
 */
vec3 CalculateFresnel(
    in vec3 surfNorm,
    in vec3 toView,
    in vec3 fresnel0)
{
	float d = max(dot(surfNorm, toView), 0.0); 
    float p = ((-5.55473 * d) - 6.98316) * d;
        
    return fresnel0 + ((1.0 - fresnel0) * pow(1.0 - d, 5.0));
}

/**
 * Standard Lambertian diffuse lighting.
 */
vec3 CalculateDiffuse(
    in vec3 albedo)
{                              
    return (albedo * ONE_OVER_PI);
}

/**
 * Cook-Torrance BRDF for analytical light sources.
 */
vec3 CalculateSpecularAnalytical(
    in    vec3  surfNorm,            // Surface normal
    in    vec3  toLight,             // Normalized vector pointing to light source
    in    vec3  toView,              // Normalized vector point to the view/camera
    in    vec3  fresnel0,            // Fresnel incidence value
    inout vec3  sfresnel,            // Final fresnel value used a kS
    in    float roughness)           // Roughness parameter (microfacet contribution)
{
    vec3 halfVector = CalculateHalfVector(toLight, toView);
    
    float ndf      = CalculateNDF(surfNorm, halfVector, roughness);
    float geoAtten = CalculateAttenuationAnalytical(surfNorm, toLight, toView, roughness);
    
    sfresnel = CalculateFresnel(surfNorm, toView, fresnel0);
    
    vec3  numerator   = (sfresnel * ndf * geoAtten);
    float denominator = 4.0 * dot(surfNorm, toLight) * dot(surfNorm, toView);
    
#ifdef SPECULAR_NDF_ONLY
    return vec3(ndf);
#elif defined(SPECULAR_ATTEN_ONLY)
    return vec3(geoAtten);
#elif defined(SPECULAR_FRESNEL_ONLY)
    return sfresnel;
#else
    return (numerator / denominator);
#endif
}

/**
 * Generates a 2D directional vector on the hemisphere from the Hammersley point set.
 * Source: http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html
 */
vec2 Hammersley(float i, float numSamples)
{   
    uint bits = uint(i);
    
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    
    float radicalInverseVDC = float(bits) * 2.3283064365386963e-10; // / 0x100000000
    
    return vec2((i / numSamples), radicalInverseVDC);
} 

/**
 * Importance Sampling to solve the radiance integral.
 *
 * We use importance sampling (as opposed to uniform or random (Monte Carlo)) to
 * generate light sample vectors that are biased to the microsurface halfway
 * vector based on the roughness. 
 */
vec3 ImportanceSample(
    in vec2  xi,
    in float roughness,
    in vec3  surfNorm)
{
	float a = (roughness * roughness);
    
    // Spherical Coordinates to Cartesian
    float phi = 2.0 * PI * xi.x;
    float cosTheta = sqrt((1.0 - xi.y) / (1.0 + (a * a - 1.0) * xi.y));
    float sinTheta = sqrt(1.0 - (cosTheta * cosTheta));
    
    vec3 H = vec3((sinTheta * cos(phi)), (sinTheta * sin(phi)), cosTheta);
    
    // From Tangent-Space to World-Space
    vec3 upVector = StepValue3(0.999, surfNorm.z, vec3(1.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0));
    vec3 tangentX = normalize(cross(upVector, surfNorm));
    vec3 tangentY = cross(surfNorm, tangentX);
    
    return ((tangentX * H.x) + (tangentY * H.y) + (surfNorm * H.z));
}

/**
 * Performs the Riemann Sum approximation of the IBL lighting integral.
 *
 * The ambient IBL source hits the surface from all angles. We average
 * the lighting contribution from a number of random light directional
 * vectors to approximate the total specular lighting.
 *
 * The number of steps is controlled by the 'IBL Steps' global.
 */
vec3 CalculateSpecularIBL(
    in    vec3  surfNorm,
    in    vec3  toView,
    in    vec3  fresnel0,
    inout vec3  sfresnel,
    in    float roughness)
{
    vec3 totalSpec = vec3(0.0);
    vec3 toSurfaceCenter = reflect(-toView, surfNorm);
    
    for(float i = 0.0; i < IBLSteps; ++i)
    {
        // The 2D hemispherical sampling vector
    	vec2 xi = Hammersley(i, IBLSteps);
        
        // Bias the Hammersley vector towards the specular lobe of the surface roughness
        vec3 H = ImportanceSample(xi, roughness, surfNorm);
        
        // The light sample vector
        vec3 L = (2.0 * dot(toView, H) * H) - toView;
        
        float NoV = clamp(dot(surfNorm, toView), 0.0, 1.0);
        float NoL = clamp(dot(surfNorm, L), 0.0, 1.0);
        float NoH = clamp(dot(surfNorm, H), 0.0, 1.0);
        float VoH = clamp(dot(toView, H), 0.0, 1.0);
        
        if(NoL > 0.0)
        {
            vec3 color = SampleEnvironment(L);
            
            float geoAtten = CalculateAttenuationIBL(roughness, NoL, NoV);
            vec3  fresnel = CalculateFresnel(surfNorm, toView, fresnel0);
            
            sfresnel += fresnel;
#ifdef SPECULAR_NDF_ONLY
            totalSpec += 0.0;
#elif defined(SPECULAR_ATTEN_ONLY)
            totalSpec += geoAtten / (NoH * NoV);
#elif defined(SPECULAR_FRESNEL_ONLY)
            totalSpec += fresnel / (NoH * NoV);
#else
            totalSpec += (color * fresnel * geoAtten * VoH) / (NoH * NoV);
#endif
        }
    }
    
    sfresnel /= IBLSteps;
    
    return (totalSpec / IBLSteps);
}

/**
 * Calculates the total light contribution for the analytical light source.
 */
vec3 CalculateLightingAnalytical(
    in vec3  surfNorm,
    in vec3  toLight,
    in vec3  toView,
    in vec3  albedo,
    in float roughness)
{
    vec3 fresnel0 = mix(vec3(0.04), albedo, Metallic);
    vec3 ks       = vec3(0.0);
    vec3 diffuse  = CalculateDiffuse(albedo);
    vec3 specular = CalculateSpecularAnalytical(surfNorm, toLight, toView, fresnel0, ks, roughness);
    vec3 kd       = (1.0 - ks);
    
    float angle = clamp(dot(surfNorm, toLight), 0.0, 1.0);
    
#ifdef DIFFUSE_ONLY
	return diffuse * angle;
#elif defined(SPECULAR_ONLY) || defined(SPECULAR_NDF_ONLY) || defined(SPECULAR_ATTEN_ONLY) || defined(SPECULAR_FRESNEL_ONLY)
    return specular * angle;
#else
    return ((kd * diffuse) + specular) * angle;
#endif
}

/**
 * Calculates the total light contribution from the ambient IBL environmental map.
 */
vec3 CalculateLightingIBL(
    in vec3  surfNorm,
    in vec3  toView,
    in vec3  albedo,
    in float roughness)
{
    vec3 fresnel0 = mix(vec3(0.04), albedo, Metallic);
    vec3 ks       = vec3(0.0);
    vec3 diffuse  = CalculateDiffuse(albedo);
    vec3 specular = CalculateSpecularIBL(surfNorm, toView, fresnel0, ks, roughness);
    vec3 kd       = (1.0 - ks);
    
#ifdef DIFFUSE_ONLY
	return diffuse;
#elif defined(SPECULAR_ONLY) || defined(SPECULAR_NDF_ONLY) || defined(SPECULAR_ATTEN_ONLY) || defined(SPECULAR_FRESNEL_ONLY)
    return specular;
#else
    return ((kd * diffuse) + specular);
#endif
}


//------------------------------------------------------------------------------------------
// Material
//------------------------------------------------------------------------------------------

vec3 Material_Apply(in RayHit hit, vec3 toView)
{
    vec3 albedo = StepValue3(AlbedoTextureOn, 0.5, SampleAlbedo(hit.surfPos, hit.surfNorm), (hit.surfNorm + 1.0) * 0.5);
    float roughness = StepValue1(RoughTextureOn, 0.5, SampleRoughness(hit.surfPos, hit.surfNorm) * Roughness, Roughness);
    
    vec3 lighting = 
        CalculateLightingAnalytical(
            hit.surfNorm,
            normalize(vec3(0.3, 1.0, 0.0)),
            toView,
            albedo,
            roughness) * DirectIntensity;
    
    lighting +=
        CalculateLightingIBL(
            hit.surfNorm,
            toView,
            albedo,
            roughness) * AmbientIntensity;

    return lighting;
}

//------------------------------------------------------------------------------------------
// Misc Effects
//------------------------------------------------------------------------------------------

vec3 HDR(in vec3 color)
{
    // Arbitrary HDR ...
    return StepValue3(UISlider(7), 0.5, vec3(1.0) - exp(-color), color);   
}

float Vignette(in vec2 uv)
{
    return 0.2 + (0.8 * pow(32.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y), 0.2));
}

vec3 OrbitAround(vec3 origin, float radius, float rate)
{
  	return vec3((origin.x + (radius * cos(iTime * rate))),
                (origin.y),
                (origin.z + (radius * sin(iTime * rate))));
}

vec3 Render(vec2 fragCoord, Camera camera)
{
    vec2 uv = (fragCoord.xy / iResolution.xy);
    vec3 final = mix(vec3(0.0), vec3(0.15), uv.y);
    
    Ray ray = Camera_GetRay(camera, uv);
    RayHit rayHit = RaymarchScene(ray);
    
    if(rayHit.hit)
    {
        final = Material_Apply(rayHit, -ray.direction);
    }
    
    return final;
}

//------------------------------------------------------------------------------------------
// Main
//------------------------------------------------------------------------------------------

const vec2 AAOffsets[4] = vec2[](
    vec2(-0.1,  0.4),
    vec2( 0.4,  0.1),
    vec2( 0.1, -0.4),
    vec2(-0.4, -0.1));

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord.xy / iResolution.xy);
    vec4 sliders = RenderSliders(fragCoord.xy / iResolution.xy);
    
    Camera camera = Camera_LookAt(OrbitAround(vec3(0.0, -0.175, 0.0), 4.0, 0.5), vec3(0.0, -0.175, 0.0));
    
    vec3 sceneColor = (Render(fragCoord + AAOffsets[0], camera) + 
                       Render(fragCoord + AAOffsets[1], camera) +
                       Render(fragCoord + AAOffsets[2], camera) +
                       Render(fragCoord + AAOffsets[3], camera)) * 0.25;
    
    vec3 finalColor = HDR(sceneColor);
    
    finalColor *= Vignette(uv);                               // Apply vignette
    finalColor  = mix(finalColor, sliders.rgb, sliders.a);    // Display the sliders
    
    fragColor.rgb = finalColor;
}
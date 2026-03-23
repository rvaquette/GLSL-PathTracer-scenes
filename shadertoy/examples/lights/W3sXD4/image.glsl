/*

This shader demonstrates light rod (aka. tube light) shading
approximation, using most representative point.

It implements the estimation described in the 2013 paper
"Real Shading in Unreal Engine 4" by Brian Karis:
https://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf

License: CC BY 4.0

--
Zavie

*/

#define MAX_STEPS 96
#define MAX_LIGHTS 6
#define EPSILON 1e-4
#define PI acos(-1.)
#define DEBUG_CONSTANT_GROUND_ROUGHNESS 0
#define DEBUG_COMPARE_WITH_POINT_LIGHT 0
#define DEBUG_SEPARATE_DIFFUSE_SPECULAR 0

vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d)
{
    return a + b * cos(2. * PI * (c * t + d));
}

struct light
{
    vec3 p0;
    vec3 p1;
    vec3 color;
};
light lights[MAX_LIGHTS];

struct material
{
    vec3 albedo;
    float roughness;
};
material materials[2];

void setLightsAndMaterials()
{
    for (int i = 0; i < MAX_LIGHTS; ++i)
    {
        vec3 p0;
        vec3 p1;

        float t = float(i) / float(MAX_LIGHTS);
        float theta = 2. * PI * t - iTime;
        float s = sin(theta);
        float c = cos(theta);

        if (i % 3 == 0)
        {
            float r = 2.5;
            float lMax = r * 2. * PI * 3. / float(MAX_LIGHTS);
            float l = lMax / 2.;

            vec3 p = vec3(r * s, 0.1, r * c);
            vec3 dp = vec3(c, 0., -s) * (l * 0.5);
            p0 = p + dp;
            p1 = p - dp;
        }
        else if (i % 3 == 1)
        {
            float r = 2.;
            float lMax = r * 2. * PI * 3. / float(MAX_LIGHTS);
            float l = lMax / 4.;

            vec3 p = vec3(r * s, 0.1, r * c);
            p0 = p;
            p1 = p + vec3(0., l, 0.);
        }
        else
        {
            float r = 1.;
            float lMax = r * 2. * PI * 3. / float(MAX_LIGHTS);
            float l = lMax / 2.;

            p0 = vec3(r * s, 1., r * c);
            p1 = p0 + l * vec3(c, 1., -s);
        }
        float id = float(i) / float(MAX_LIGHTS);
        id = fract(1001. * id);
        vec3 color = palette(id, vec3(0.5), vec3(0.5), vec3(1.), vec3(0., 0.33, 0.67));
#if DEBUG_COMPARE_WITH_POINT_LIGHT
        p1 = p0;
#endif
        lights[i] = light(p0, p1, color * 10. / float(MAX_LIGHTS));
    }
    
    materials[0] = material(vec3(0.01, 0.5, 1.), 0.1);
    materials[1] = material(vec3(0.2), 0.1);
}

float sceneSDF(vec3 p, out int mid)
{
    float d = 1e6;

    float sphere = length(p) - 1.;
    if (sphere < d)
    {
        d = sphere;
        mid = 0;
    }

    float ground = p.y + 0.0;
    if (ground < d)
    {
        d = ground;
        mid = 1;
    }

    for (int i = 0; i < MAX_LIGHTS; ++i)
    {
        light l = lights[i];
        vec3 Ld = l.p1 - l.p0;
        float h = clamp(dot(p - l.p0, Ld) / dot(Ld, Ld), 0., 1.);
        float rod = length(p - l.p0 - h * Ld) - 0.05;
        if (rod < d)
        {
            d = rod;
            mid = -i - 1;
        }
    }

    return d;
}

vec3 evalNormal(vec3 p, float fp)
{
    const float h = 1e-3;
    const vec2 k = vec2(1., -1.);
    int dummy;
    return normalize(
        k.xyy * sceneSDF(p + k.xyy * h, dummy) + 
        k.yyx * sceneSDF(p + k.yyx * h, dummy) + 
        k.yxy * sceneSDF(p + k.yxy * h, dummy) + 
        k.xxx * sceneSDF(p + k.xxx * h, dummy)
    );
}

vec3 cookTorrance(
    vec3 f0,
	float roughness,
	vec3 NcrossH,
	float VdotH,
    float NdotL,
    float NdotV)
{
	float alpha = roughness * roughness;
    float sqrAlpha = alpha * alpha;

	float distribution = dot(NcrossH, NcrossH) * (1. - sqrAlpha) + sqrAlpha;
	float D = sqrAlpha / (PI * distribution * distribution);

	float SmithL = (2. * NdotL) / max(1e-8, NdotL + sqrt(NdotL * NdotL * (1. - sqrAlpha) + sqrAlpha));
	float SmithV = (2. * NdotV) / max(1e-8, NdotV + sqrt(NdotV * NdotV * (1. - sqrAlpha) + sqrAlpha));
	float G = SmithL * SmithV;

	float x = 1. - VdotH;
	x = x*x*x*x*x;
	vec3 F = x + f0 * (1. - x);

	return F * (D * G * 0.25 / max(1e-8, NdotV * NdotL));
}

vec3 pointLightContribution(material m, light l, vec3 p, vec3 N, vec3 V)
{
    vec3 L0 = l.p0 - p;
    float d0 = length(L0);
    vec3 L = L0 / d0;

    float NdotL = dot(N, L);
    if (NdotL <= 0.)
        return vec3(0.);

    vec3 intensity = l.color / (d0 * d0);
    vec3 radiance = intensity * NdotL;

    vec3 H = normalize(L + V);
    vec3 NcrossH = cross(N, H);
    float VdotH = clamp(dot(V, H), 0., 1.);
    float NdotV = clamp(dot(N, V), 0., 1.);

    vec3 diff = m.albedo;
    vec3 spec = cookTorrance(vec3(0.04), m.roughness, NcrossH, VdotH, NdotL, NdotV);

    return radiance * (diff + spec);
}

vec3 rodLightContribution(material m, light l, vec3 p, vec3 N, vec3 V)
{
    vec3 L0 = l.p0 - p;
    vec3 L1 = l.p1 - p;
    float d0 = length(L0);
    float d1 = length(L1);
    
    float NdotL0 = dot(N, L0) / d0;
    float NdotL1 = dot(N, L1) / d1;

    float topPart = 2. * clamp((NdotL0 + NdotL1) / 2., 0., 1.);
    float bottomPart = d0 * d1 + dot(L0, L1);
    float contribution = topPart / bottomPart;
    // The Karis paper has a +2 term in the bottom part,
    // but I found the result to better match point lights
    // when the length is zero.
    // Then again, there could be an implementation error.

    if (contribution <= 0.)
    {
        return vec3(0.);
    }

    vec3 irradiance = l.color * contribution;

    vec3 Ld = l.p1 - l.p0;
    vec3 R = reflect(-V, N);
    float RdotLd = dot(R, Ld);
    
    float t = clamp((dot(R, L0) * RdotLd - dot(L0, Ld)) / (dot(Ld, Ld) - RdotLd * RdotLd), 0., 1.);
    vec3 Lmrp = mix(L0, L1, t);

    vec3 L = normalize(Lmrp);
    float NdotL = clamp(dot(N, L), 0., 1.);

    vec3 H = normalize(L + V);
    vec3 NcrossH = cross(N, H);
    float VdotH = clamp(dot(V, H), 0., 1.);
    float NdotV = clamp(dot(N, V), 0., 1.);

    vec3 diff = m.albedo;
    vec3 spec = cookTorrance(vec3(0.04), m.roughness, NcrossH, VdotH, NdotL, NdotV);
#if DEBUG_SEPARATE_DIFFUSE_SPECULAR
    if (gl_FragCoord.x < iResolution.x / 3.)
    {
        spec = vec3(0.);
    }
    if (gl_FragCoord.x > iResolution.x * 2. / 3.)
    {
        diff = vec3(0.);
    }
#endif

    return irradiance * (diff + spec);
}

vec3 evalRadiance(int mid, vec3 p, vec3 V, vec3 N)
{
    if (mid < 0)
    {
        return lights[-mid - 1].color;
    }
    material m = materials[mid];
#if !DEBUG_CONSTANT_GROUND_ROUGHNESS
    if (mid == 1)
    {
        m.roughness = 1. - texture(iChannel0, p.xz/4.).r;
    }
#endif

    vec3 radiance = vec3(0.);
    for (int i = 0; i < MAX_LIGHTS; ++i)
    {
#if DEBUG_COMPARE_WITH_POINT_LIGHT
        if (gl_FragCoord.x < iResolution.x / 2.)
        {
            radiance += pointLightContribution(m, lights[i], p, N, V);
        }
        else
#endif
        {
            radiance += rodLightContribution(m, lights[i], p, N, V);
        }
    }
    return radiance;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord/iResolution.xy * 2. - 1.) * vec2(1., iResolution.y / iResolution.x);
    setLightsAndMaterials();

    vec3 ro = vec3(0, 2., 10.);
    vec3 rd = normalize(vec3(uv.x, uv.y - 0.5, -3.));

    vec3 p;
    float d;
    float t = 0.;
    int mid = 0;

#define ZERO (min(iFrame,0))
    for (int i = ZERO; i < MAX_STEPS; ++i)
    {
        p = ro + t * rd;
        d = sceneSDF(p, mid);
        if (d < EPSILON)
        {
            break;
        }
        t += d;
    }

    vec3 radiance = vec3(0.);
    if (d < 1024. * EPSILON)
    {
        vec3 N = evalNormal(p, d);
        radiance = evalRadiance(mid, p, -rd, N);
    }
    
    vec3 color = pow(radiance, vec3(1./2.2));
    fragColor = vec4(color, 1.);
}


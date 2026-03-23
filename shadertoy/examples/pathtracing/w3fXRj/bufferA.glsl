const float SampleNb = 2.;
const int   BounceNb = 8;

uvec4 seed;

struct DiskLight {
    float height;
    float radius;
    vec3  strength;
    uint  lightId;
};

DiskLight getLight(uint id) 
{
   const DiskLight light = DiskLight(5., 2., 10. * vec3(1.000,1.000,1.000), 0u);
   return light;
}

LightSample sampleLight(vec3 p) 
{
    vec2 uv;
    
    float lightPdf;
    DiskLight light = getLight(0u);
    vec3  lightPos  = sampleDisk(light.height, light.radius, prng(seed).xy);
    vec3  wi        = normalize(lightPos - p);
    float pdf       = length2(lightPos - p) / max(1e-4, abs(dot(vec3(0., -1., 0.), -wi)) * getDiskArea(light.radius));
                        
    return LightSample(wi, light.strength, pdf);
}

//-- BSDF implementation
// For all these functions, ro and rd are transformed s.t. n = (0., 0., 1.)

//- Diffuse
vec3 evalDisneyDiffuse(HitInfo hit, vec3 wo, vec3 wi)
{
    float alpha = max(1e-4, hit.material.roughness * hit.material.roughness);
    
    vec3  h   = normalize(wo + wi);
    float wih = clamp(dot(wi, h), 0., 1.);
    float won = clamp(abs(wo.z), 1e-4, 1.);
    float win = clamp(abs(wi.z), 1e-4, 1.);
    
    float fd90 = 0.5 + 2. * alpha * wih * wih;
    float f1   = 1. + (fd90 - 1.) * pow(1. - win, 5.);
    float f2   = 1. + (fd90 - 1.) * pow(1. - won, 5.);
    return hit.material.baseColor * OneOverPi * (1. - hit.material.metallic) * f1 * f2;
}

vec3 sampleDisneyDiffuse(HitInfo hit, vec3 wo, const vec2 u) 
{
    vec3 wi = sampleCosine(u);
    if (wo.z < 0.)
        wi.z *= -1.;
    return wi;
}

float getPDFDisneyDiffuse(HitInfo hit, vec3 wo, vec3 wi) 
{
    return wo.z * wi.z > 0. ? abs(wi.z) * OneOverPi : 0.;
}

//- Specular
float evalSpecularReflection(HitInfo hit, vec3 wo, vec3 wi) 
{
    float roughness = max(1e-4, hit.material.roughness);
    float alpha     = max(1e-4, roughness * roughness);
    float alpha2    = max(1e-4, alpha * alpha);  

    vec3  h   = normalize(wo + wi);
    float hn  = clamp(abs(h.z),  1e-4, 1.);
    float won = clamp(abs(wo.z), 1e-4, 1.);
    float win = clamp(abs(wi.z), 1e-4, 1.);

    float g = getSmithG2GGX(won, win, alpha2);
    float d = getDGGX(hn, alpha2);

    return g * d;
}

float getPDFSpecularReflection(HitInfo hit, vec3 wo, vec3 wi) 
{
    float roughness = max(1e-4, hit.material.roughness);
    float alpha     = max(1e-4, roughness * roughness);
    float alpha2    = max(1e-4, alpha * alpha);  
    
	vec3  h   = normalize(wo + wi);
    float hn  = clamp(abs(h.z),   1e-4, 1.);
    float won = clamp(abs(wo.z),  1e-4, 1.);
    float win = clamp(abs(wi.z),  1e-4, 1.);
    float wih = clamp(dot(wi, h), 1e-4, 1.);

    float g1 = getSmithG1GGX(wih, alpha2);
    float d  = getDGGX(hn, alpha2);
    
    // Pdf of the VNDF times the Jacobian of the reflection operator
    return d * g1 * wih / max(1e-4, 4. * win * wih);
}

float getClearCoatRoughness(HitInfo hit) 
{
    return 0.6 * (1. - hit.material.clearcoatGloss);
}

float evalClearCoat(HitInfo hit, vec3 wo, vec3 wi) 
{
    float roughness = max(1e-4, getClearCoatRoughness(hit));
    float alpha     = max(1e-4, roughness * roughness);
    float alpha2    = max(1e-4, alpha * alpha);  

    vec3  h   = normalize(wo + wi);
    float hn  = clamp(abs(h.z),  1e-4, 1.);
    float won = clamp(abs(wo.z), 1e-4, 1.);
    float win = clamp(abs(wi.z), 1e-4, 1.);

    float g = getSmithG2GGX(won, win, alpha2);
    float d = getDGGX(hn, alpha2);

    return hit.material.clearcoat * 0.25 * g * d;
}

float getPDFClearCoat(HitInfo hit, vec3 wo, vec3 wi) 
{
    float roughness = max(1e-4, getClearCoatRoughness(hit));
    float alpha     = max(1e-4, roughness * roughness);
    float alpha2    = max(1e-4, alpha * alpha);  
    
	vec3  h   = normalize(wo + wi);
    float hn  = clamp(abs(h.z),   1e-4, 1.);
    float won = clamp(abs(wo.z),  1e-4, 1.);
    float win = clamp(abs(wi.z),  1e-4, 1.);
    float wih = clamp(dot(wi, h), 1e-4, 1.);

    float g1 = getSmithG1GGX(wih, alpha2);
    float d  = getDGGX(hn, alpha2);
    
    // Pdf of the VNDF times the Jacobian of the reflection operator
    return hit.material.clearcoat * 0.25 * d * g1 * wih / max(1e-4, 4. * win * wih);
}

float evalSpecularTransmission(HitInfo hit, vec3 wo, vec3 wi) 
{
    float roughness = max(1e-4, hit.material.roughness);
    float alpha     = max(1e-4, roughness * roughness);
    float alpha2    = max(1e-4, alpha * alpha);  

    float inside   = sign(wo.z);
    bool  isInside = inside < 0.; 

    const float AirIOR = 1.f;
    float etaI = isInside ? AirIOR : hit.material.ior;
    float etaT = isInside ? hit.material.ior : AirIOR;

    vec3  h   = normalize(-(etaI * wi + etaT * wo));
    float hn  = clamp(abs(h.z),        1e-4, 1.);
    float won = clamp(abs(wo.z),       1e-4, 1.);
    float woh = clamp(abs(dot(wo, h)), 1e-4, 1.);
    float win = clamp(abs(wi.z),       1e-4, 1.);
    float wih = clamp(abs(dot(wi, h)), 1e-4, 1.);

    float g2 = getSmithG1GGX(wih, alpha2) * getSmithG1GGX(woh, alpha2);
    float d  = getDGGX(hn, alpha2);
    float w  = wih * woh / max(1e-4, win * won);
    float s  = etaI * wih + etaT * woh;
    
    return w * etaT*etaT * g2 * d / max(1e-4, s*s);
}

float getPDFSpecularTransmission(HitInfo hit, vec3 wo, vec3 wi) 
{
    float roughness = max(1e-4, hit.material.roughness);
    float alpha     = max(1e-4, roughness * roughness);
    float alpha2    = max(1e-4, alpha * alpha);  
    
    float inside   = sign(wo.z);
    bool  isInside = inside < 0.; 

    const float AirIOR = 1.f;
    float etaI = isInside ? AirIOR : hit.material.ior;
    float etaT = isInside ? hit.material.ior : AirIOR;

    vec3  h   = normalize(-(etaI * wi + etaT * wo));
    float hn  = clamp(abs(h.z),        1e-4, 1.);
    float won = clamp(abs(wo.z),       1e-4, 1.);
    float woh = clamp(abs(dot(wo, h)), 1e-4, 1.);
    float win = clamp(abs(wi.z),       1e-4, 1.);
    float wih = clamp(abs(dot(wi, h)), 1e-4, 1.);

    float g1 = getSmithG1GGX(wih, alpha2);
    float d  = getDGGX(hn, alpha2);
    
    float s                    = etaI * wih + etaT * woh;
    float transmissionJacobian = etaT*etaT * woh / max(1e-4, s*s);
    float vndf                 = g1 * wih * d    / win;
    
    return transmissionJacobian * vndf;
}

// Linear interpolation between Fresnel metallic and dielectric based on 
// material.metallic. 
// Found: https://schuttejoe.github.io/post/disneybsdf/
vec3 getDisneyFresnel(HitInfo hit, vec3 wo, vec3 wi, vec3 h)
{
    float luminance = getLuminance(hit.material.baseColor);
    vec3 tint       = luminance > 0. ? hit.material.baseColor * (1. / luminance) : vec3(1.);
    
    vec3 baseR0 = vec3(iorToReflectance(hit.material.ior));
    vec3 r0     = mix(baseR0, tint, hit.material.specularTint);
    r0          = mix(r0, hit.material.baseColor, hit.material.metallic);

    float wih = clamp(abs(dot(wi, h)), 1e-4, 1.);
    float woh = clamp(abs(dot(wo, h)), 1e-4, 1.);
    
    vec3 dielectricF = schlickFresnel(baseR0, woh);
    vec3 metallicF   = schlickFresnel(r0, wih);
    
    return mix(dielectricF, metallicF, hit.material.metallic);
}

vec3 evalBSDF(HitInfo hit, vec3 wo, vec3 wi) 
{
    float win       = clamp(abs(wi.z),       1e-4, 1.);
    float won       = clamp(abs(wo.z),       1e-4, 1.);
    bool  entering  = wi.z > 0.;
    bool  doReflect = wi.z * wo.z > 0.f;
    
    vec3 weight = vec3(1.);
    if (!entering && hit.material.specularTransmission > 0.f)
        weight *= exp(log(hit.material.transmittance) * abs(hit.t) / hit.material.atDistance);

    const float AirIOR = 1.f;
    float etaI = entering ? hit.material.ior : AirIOR;
    float etaT = entering ? AirIOR : hit.material.ior;

    if( doReflect )
    {
        vec3 h = normalize(wi + wo);
        vec3 f = getDisneyFresnel(hit, wi, wo, h);

        float roughness = max(1e-4, hit.material.roughness);
        float alpha     = max(1e-4, roughness * roughness);
        float alpha2    = max(1e-4, alpha * alpha);

        float nh  = clamp(abs(h.z),        1e-4, 1.);
        float lh  = clamp(abs(dot(wi, h)), 1e-4, 1.);

        float diffuseWeight = 1. - hit.material.specularTransmission;
        vec3  diffuse       = diffuseWeight * evalDisneyDiffuse(hit, wo, wi);
        float specular      = evalSpecularReflection(hit, wo, wi);
        
        float woh = clamp(abs(dot(wo, h)), 1e-4, 1.);
        float ccf = schlickFresnel(vec3(iorToReflectance(1.5)), woh).x;

        return weight * ((1. - f) * diffuse + f * specular + ccf * evalClearCoat(hit, wo, wi));
    }
    else 
    {
        vec3 h = normalize(-(etaI * wi + etaT * wo));
        vec3 f = getDisneyFresnel(hit, wi, wo, h);

        float transmissionWeight   = hit.material.specularTransmission;
        float specularTransmission = transmissionWeight * evalSpecularTransmission(hit, wo, wi);
        return weight * (sqrt(hit.material.baseColor) * (1. - f) * specularTransmission);
    }
}

vec3 sampleBSDF(HitInfo hit, vec3 wo, out vec3 weight, out float pdf)
{
    float roughness = max(1e-4, hit.material.roughness);
    float alpha     = max(1e-4, roughness * roughness);
    float alpha2    = max(1e-4, alpha * alpha);
    
    float inside   = sign(wo.z);
    bool  isInside = inside < 0.; 

    pdf    = 1.;
    weight = vec3(1.);
    if (isInside && hit.material.specularTransmission > 0.f)
       weight *= exp(log(hit.material.transmittance) * abs(hit.t) / hit.material.atDistance);

    vec4 u = prng(seed);
    vec3 h = hit.normal;
    
    vec2 alea = prng(seed).xy;
    if(hit.material.clearcoat > 0.) {
        float ccRoughness = getClearCoatRoughness(hit);
        float ccAlpha     = max(1e-4, ccRoughness * ccRoughness);
        float ccAlpha2    = max(1e-4, ccAlpha * ccAlpha);

        vec3 ccH = h;
        if(ccRoughness > .0)
            ccH = SampleVndf_GGX(u.xy, wo, vec2(ccAlpha));
        
        float woh = clamp(abs(dot(wo, ccH)), 1e-4, 1.);
        float ccf = schlickFresnel(vec3(iorToReflectance(1.5)), woh).x;
        if(alea.y < ccf) {
            vec3  wi = reflect(-wo,ccH);

            float hn  = clamp(abs(ccH.z),        1e-4, 1.);
            float woh = clamp(abs(dot(wo, ccH)), 1e-4, 1.);
            float wih = clamp(abs(dot(wi, ccH)), 1e-4, 1.);

            float g1 = getSmithG1GGX(woh, ccAlpha2);
            float g2 = getSmithG1GGX(wih, ccAlpha2) * g1;
            weight  *= hit.material.clearcoat * g2 / max(1e-4, g1);
            pdf     *= 1.;
            return wi;
        }
    }
    
    if (roughness > 0.)
        h = SampleVndf_GGX(u.xy, wo, vec2(alpha));

    vec3 f = getDisneyFresnel(hit, wo, wo, h);

    float specularWeight = length(f); 
    bool  fullSpecular   = roughness == 0. && hit.material.metallic == 1.;
    float type           = fullSpecular ? 0. : prng(seed).x;
    
#define GROUND_TRUTH

    if (type < specularWeight)
    {
        vec3  wi = reflect(-wo, h);

#ifdef GROUND_TRUTH
        float hn  = clamp(abs(h.z),        1e-4, 1.);
        float woh = clamp(abs(dot(wo, h)), 1e-4, 1.);
        float wih = clamp(abs(dot(wi, h)), 1e-4, 1.);

        float g1 = getSmithG1GGX(woh, alpha2);
        float g2 = getSmithG1GGX(wih, alpha2) * g1;
        weight  *= sqrt(hit.material.baseColor) * g2 / max(1e-4, g1);
        pdf     *= 1.;
#else
        weight *= f * evalSpecularReflection(hit, wo, wi) ;
        pdf    *= getPDFSpecularReflection(hit, wo, wi);
        pdf    *= fullSpecular ? 1. : specularWeight;
#endif
        return wi;
    }
   
    float transmissionType           = type - specularWeight;
    float specularTransmissionWeight = (1. - specularWeight) * hit.material.specularTransmission;
    if(transmissionType < specularTransmissionWeight) 
    {
        const float AirIOR = 1.f;
        float etaI = isInside ? hit.material.ior : AirIOR;
        float etaT = isInside ? AirIOR : hit.material.ior;
        vec3 wi    = refract(-wo, h, etaI / etaT);

        // surface absorption: we multiply the refraction result by the square root of the surface color,
        // which, after both the entering and exiting scattering events are accounted for, produces the
        // expected albedo.

#ifdef GROUND_TRUTH
        float woh = clamp(abs(dot(wo, h)), 1e-4, 1.);
        float wih = clamp(abs(dot(wi, h)), 1e-4, 1.);

        float g1 = getSmithG1GGX(wih, alpha2);
        float g2 = getSmithG1GGX(woh, alpha2) * g1;
        weight *= sqrt(hit.material.baseColor) * g2 / max(1e-4, g1 * abs(wo.z));
        pdf = 1.;
#else
        weight *= sqrt(hit.material.baseColor) * hit.material.specularTransmission * evalSpecularTransmission(hit, wo, wi);
        pdf    *= hit.material.specularTransmission * getPDFSpecularTransmission(hit, wo, wi);
#endif
#undef GROUND_TRUTH
        return wi;
    }
    
    vec3 wi = sampleDisneyDiffuse(hit, wo, prng(seed).xy);

    weight = (1. - hit.material.specularTransmission) * (1. - f) * evalDisneyDiffuse(hit, wo, wi); 
    pdf    = (1. - hit.material.specularTransmission) * getPDFDisneyDiffuse(hit, wo, wi);

    return wi;
}

float getPDFBSDF(HitInfo hit, vec3 wo, vec3 wi) 
{
    float specular     = getPDFSpecularReflection(hit, wo, wi);
    float transmission = hit.material.specularTransmission  * getPDFSpecularTransmission(hit, wo, wi);
    float diffuse      = getPDFDisneyDiffuse(hit, wo, wi);
    float clearcoat    = getPDFClearCoat(hit, wo, wi);

    return (specular + transmission + diffuse + clearcoat) / 4.;
}

//-- Geometry acquisition
HitInfo trace(vec3 ro, vec3 rd) 
{
    HitInfo hit = defaultHitInfo();

    const uint HashOffset = 15u;
    const float NbSpheres = 7.;
    const float r = .7;
    for(float i = 0.; i < NbSpheres; i++)
    {
        for(float j = 0.; j < NbSpheres; j++) 
        {
            vec3 c = vec3(i + .5 - NbSpheres/2., 0., j  + .5 - NbSpheres/2.) * r * 2.;
            vec2 tt = iSphere(ro, rd, c, r);

            float t = (tt.x < tt.y && tt.x >= 0.) ? tt.x : tt.y;
            if(t > 0. && (t < hit.t || hit.t < 0.))
            {
                hit.t      = t;
                hit.normal = ((ro + rd * t) - c) / r;
                
                uint hashOffset = HashOffset + uint(i * NbSpheres + j);
                float hash = hash11(hashOffset);
                
                hit.material              = defaultMaterial();
                hit.material.baseColor    = hash31(hashOffset);
                hit.material.metallic     = step(.7, hash) * hash11(hashOffset - 2u);
                hit.material.specularTint = hit.material.metallic * hash11(hashOffset - 4u);
                hit.material.roughness    = hash11(hashOffset - 1u) * .5;
                hit.material.ior          = 1.01 + 1.5 * hash;
                
                hit.material.specularTransmission = (1. - hit.material.metallic) * hash11(hashOffset - 2u);
                hit.material.transmittance        = hash31(hashOffset - 4u);
                hit.material.atDistance           = hash11(hashOffset - 5u) * 1.;
                
                hit.material.clearcoat      = hash11(hashOffset - 7u);
                hit.material.clearcoatGloss = hash11(hashOffset - 8u);
            }
        }
    }
    
    vec3 boxNormal;
    vec2 tt = iBox(ro + vec3(0., r, 0.), rd, vec3(NbSpheres, 0.1, NbSpheres) * (r + .1), boxNormal);
    float t = tt.x < tt.y && tt.x >= 0. ? tt.x : tt.y;
    if(t > 0. && (t < hit.t || hit.t < 0.)) {
        hit.t = t, hit.normal = boxNormal;
        hit.material = defaultMaterial();
        hit.material.baseColor = vec3(1.);
        hit.material.roughness = .3;
        hit.material.metallic  = .0;
    }
    
    return hit;
}

void getCamera(vec2 fragCoord, vec2 jitter, out vec3 ro, out vec3 rd) {
    vec2 uv = (fragCoord+(jitter * 2. - 1.)+.5-iResolution.xy*0.5)/iResolution.y;
    uv.y = -uv.y;
    
    vec2 mouse = texelFetch(iChannel0, ivec2(0), 0).zw;
    
    ro           = vec3(max(1e-4, mouse.y) * 4e-2, 4., 0.);
    vec3 forward = normalize( /* target */ - ro);
    vec3 right   = normalize(cross(forward, vec3(0., 1., 0.)));
    vec3 up      = normalize(cross(forward, right)); 
    
    mat3 ruf = mat3(right, up, forward);
    float a  = tan(Pi * .35);
    rd       = ruf * normalize(vec3(uv, a));
    
    float xStep = mouse.x / iResolution.x;
    vec4 q = quaternion(xStep * 2. * Pi, vec3(0., 1., 0.));
    ro = multiply(q, ro), rd = multiply(q, rd);    
}

vec4 getBlueNoise(vec2 fragCoord, int frame) 
{
    // Reference: https://www.shadertoy.com/view/tlySzR
    ivec2 p = ivec2(fragCoord);
    p = (p+frame*ivec2(113,127)) & 1023;
    return texelFetch(iChannel2, p, 0);
}

vec3 render(vec2 fragCoord, int frame)
{
	seed       = uvec4( fragCoord.x, fragCoord.y, frame, 0 );
    vec2 noise = getBlueNoise(fragCoord, frame).xy;
    
    vec3 ro, rd;
    getCamera(fragCoord, noise, ro, rd);
    
    // Light integration
    vec3 throughput = vec3(1.);
    vec3 finalColor = vec3(0.);
    for(int b = 0; b < BounceNb; b++) 
    {
        HitInfo hit = trace(ro, rd);
        
        if(hit.t < 0.) 
        {
            finalColor += throughput * texture(iChannel1, rd).rgb;
            break;
        }
        
        vec3 position  = ro + rd * hit.t;
        vec3 n         = hit.normal;
        float inside   = sign(dot(n, -rd));
        bool  isInside = inside < 0.; 

        vec3 pposition = offsetRay(position, hit.normal * inside);
        vec4 transform = toLocalZ(hit.normal);
        hit.normal     = vec3(0., 0., 1.);
        vec3 woLocal   = normalize(multiply(transform, -rd));
        vec3 direct    = vec3( 0. );

        // Direct lighting
        // Light sampling
        {
            LightSample lightSample = sampleLight(pposition);
            
            vec3  wiLocal  = normalize( multiply(transform, lightSample.wi) );
            float cosTheta = wiLocal.z;
            if( lightSample.pdf > 0. && cosTheta > 0. ) 
            {
                if( trace(pposition, lightSample.wi).t < 0. ) 
                {
                    vec3 brdf = evalBSDF(hit, woLocal, wiLocal) * cosTheta;
                    
                    float scatteringPdf = getPDFBSDF( hit, woLocal, wiLocal ); 
                    float weight		= powerHeuristic( 1, lightSample.pdf, 1, scatteringPdf );

                    direct += brdf * lightSample.intensity * weight / max(1e-4, lightSample.pdf);
                }
            }            
        }
        
        // Sampling BRDF
        {
            float scatteringPdf = 0.;
            vec3  brdf          = vec3(0.);
            vec3  wiLocal       = sampleBSDF( hit, woLocal, brdf, scatteringPdf );
            float cosTheta      = wiLocal.z;
            if( scatteringPdf > 0. && cosTheta > 0. ) 
            {
                vec3 wi = normalize(multiply(conjugate(transform), wiLocal));

                if(trace(pposition, wi).t < 0.)
                {
                    DiskLight light = getLight(0u);
                    float tt        = iDisk(pposition, wi, vec3(0., light.height, 0.), vec3(0., -1., 0.), light.radius);
                    if(tt > 0.)
                    {
                        vec3  lightPos = pposition + wi * tt;
                        float lightPdf = length2(lightPos - pposition) / max(1e-4, abs(dot(vec3(0., -1., 0.), -wi)) * getDiskArea(light.radius));

                        float weight = powerHeuristic(1, scatteringPdf, 1, lightPdf);

                        direct += brdf * cosTheta * light.strength * weight / max(1e-4, scatteringPdf);
                    }
                }
            }
        }
        finalColor += throughput * direct;

        float scatteringPdf = 0.;
        vec3  weight        = vec3(0.);
        vec3  wiLocal       = sampleBSDF(hit, woLocal, weight, scatteringPdf);
                
        float cosTheta = abs(woLocal.z);
        throughput    *= weight * cosTheta / max(1e-4, scatteringPdf);

        if(any(isinf(throughput)) || any(isnan(throughput)) )
            return vec3(1., 0., 0.);
    
        float luminance = getLuminance(throughput);
        if(luminance == 0.)
            return vec3(0.);

        // Russian Roulette
        // Crash course in BRDF implementation
        float rr = min(luminance, .95f);
        // https://computergraphics.stackexchange.com/a/2325
        // float rr = max(throughput.x, max(throughput.y, throughput.z));
        if (getBlueNoise(fragCoord, frame * int(SampleNb) + b).x > rr)
            break;
            
        throughput *= 1. / rr;

        rd = normalize(multiply(conjugate(transform), wiLocal));
        ro = offsetRay(position, n * sign(dot(n, rd)));
    }

    return finalColor;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    ivec2 v = ivec2(fragCoord);
    
    vec4 lastData       = texelFetch(iChannel0, ivec2(0), 0);
    vec2 lastResolution = lastData.xy;
    vec2 lastMouse      = lastData.zw;
    vec4 data = texture( iChannel0, fragCoord/iResolution.xy );
    if( iFrame==0 ) data = vec4(0.0);

    vec3 col = vec3(0.);
    for (float i = 0.; i < SampleNb; i++) 
        col += render(fragCoord, int(data.w + i));
    col /= SampleNb;
        
    if( length(lastResolution - iResolution.xy) > 0. || length(lastMouse - iMouse.xy) > 0. ) 
         data = vec4(col, 0.);
     data = vec4(col, 1.) + (data.w > 0. ? data : vec4(0.));
    
    fragColor = data;
    if(fragCoord.x < 1. && fragCoord.y < 1.)
    {
        fragColor.xy = iResolution.xy;
        fragColor.zw = iMouse.xy;
    }
}

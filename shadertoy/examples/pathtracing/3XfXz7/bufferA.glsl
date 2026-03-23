
vec4 data = vec4(0);

vec3 sampleTriplanarTexture(sampler2D channel, vec3 normal, vec3 position, float sharpness)
{
    vec3 n = pow(abs(normal), vec3(sharpness));
    n /= n.x + n.y + n.z;
    
    vec3 tx = sRGBToLinear(texture(channel, position.zy).rgb);
    vec3 ty = sRGBToLinear(texture(channel, position.xz).rgb);
    vec3 tz = sRGBToLinear(texture(channel, position.yx).rgb);
    
    return tx * n.x + ty * n.y + tz * n.z;
}

vec3 sampleEquirectangularTexture(sampler2D channel, vec3 normal, vec2 scale, vec2 offset)
{
    float theta = atan(normal.z, normal.x) / TAU + 0.5;
    float phi = acos(normal.y) / PI;
    
    return sRGBToLinear(texture(channel, (vec2(theta, phi) + offset) * scale).rgb);
}

vec3 sampleEquirectangularTexture(sampler2D channel, vec3 normal)
{
    return sampleEquirectangularTexture(channel, normal, vec2(1), vec2(0));
}

vec3 getSkybox(vec3 direction)
{
#ifdef WHITE_FURNACE_TEST
    return vec3(1);
#else
    vec3 sky = sRGBToLinear(texture(iChannel1, direction).rgb);
    vec3 stars = sampleEquirectangularTexture(iChannel2, direction, 5.0*vec2(1, 0.5), vec2(0.23, 0.285));
#ifdef ENABLE_SKY_STARS
    sky += 40.0*pow(stars, vec3(5.0));
#endif
    return SKYBOX_STRENGTH * sky;
#endif
}

vec3 getColor(int i)
{
    vec3 color = vec3(1);
    if (i == 0)
        color = vec3(1.00, 0.85, 0.57); // Gold
    else if (i == 1)
        color = vec3(0.98, 0.90, 0.59); // Brass
    else if (i == 2)
        color = vec3(0.97, 0.74, 0.62); // Copper
    else if (i == 3)
        color = vec3(0.77, 0.78, 0.78); // Iron
    else if (i == 4)
        color = vec3(0.97, 0.96, 0.91); // Silver
        
    return sRGBToLinear(color);
}

void sceneIntersect(Ray ray, out HitInfo hit, out Material mat)
{   
    hit = NewHitInfo();
    mat = DefaultMaterial();
    
#if SCENE == 0
    #define NUM_SPHERES 5
    for (int x = 0; x < NUM_SPHERES; x++)
    for (int y = 0; y < NUM_SPHERES; y++)
    {
        float radius = 0.4;
        float spacing = 0.05;
        float xp = (float(x) - float(NUM_SPHERES - 1) / 2.0) * (2.0 * radius + spacing);
        float yp = (float(y) - float(NUM_SPHERES - 1) / 2.0) * (2.0 * radius + spacing);
        float roughness = float(x) / float(NUM_SPHERES - 1) * 0.8 + 0.2;//float(i) * 0.2;
        float metallic = float(y) / float(NUM_SPHERES - 1) * 0.5 + 0.5;
        
        metallic = saturate(metallic);
        roughness = saturate(roughness);
        roughness *= roughness;
        
        if (sphereIntersect(ray, vec3(-xp, 0, -yp), radius, hit))
        {
            vec3 p = ray.origin + ray.direction * hit.t;
            
            float scale = 0.6;
            float e = 2.0 / iChannelResolution[2].x;
            vec3 tex = sampleEquirectangularTexture(iChannel2, hit.normal, scale * vec2(1.0, 0.5), vec2(xp, yp));
            vec3 texDx = sampleEquirectangularTexture(iChannel2, hit.normal, scale * vec2(1.0, 0.5), vec2(xp + e, yp));
            vec3 texDy = sampleEquirectangularTexture(iChannel2, hit.normal, scale * vec2(1.0, 0.5), vec2(xp, yp + e * 0.5));
            
            vec3 N = hit.normal;
            vec3 A = abs(N.z) > 0.9999 ? vec3(0, 1, 0) : vec3(0, 0, 1);
            vec3 T = normalize(cross(N, A));
            vec3 B = cross(T, N);
            
            float h = luminance(tex);
            float hx = luminance(texDx);
            float hy = luminance(texDy);
            vec3 tn = normalize(vec3(h - hx, (h - hy) * 2.0, e));
            //vec3 tex = sampleTriplanarTexture(iChannel2, hit.normal, p * 0.3, 5.0);
            float m = smoothstep(0.03, 0.1, luminance(tex));
            
            tn = normalize(mix(vec3(0, 0, 1), tn, 1.0 - m));
            
            hit.bumpNormal = normalize(T * tn.x + B * tn.y + N * tn.z);
            
            metallic = min(metallic, m);
            roughness = max(roughness, 1.0 - m);
            
            uint r = uint(x+y*NUM_SPHERES)+23u;
            uint r2 = r+123u;
            
            #if COLOR == 0
            vec3 color = mix(palette(hash(r)), 1.0-palette(hash(r2)), pow(mix(abs(dot(hit.normal, ray.direction)), 1.0, roughness), 1.5));
            #elif COLOR == 1
            vec3 color = getColor(y);
            #else
            vec3 color = vec3(1);
            #endif
            
            color = mix(saturate(tex * 5.0), color, m);
            
            mat = Material(color, vec3(0), roughness, metallic, 0.0, 1.0, 1.0);
            
            #ifdef WHITE_FURNACE_TEST
            mat.color = vec3(1);
            #endif
        }
    }
#else
    if (sphereIntersect(ray, vec3(0, 0, 0), 1.0, hit))
    {
        mat = DefaultMaterial();
        //mat.color = vec3(1, 0.5, 0.5);
        //mat.color = mix(vec3(1, 0.5, 0.5), vec3(0.3, 0.6, 1.0), pow(abs(dot(hit.normal, ray.direction)), 1.5));
        mat.transmission = 0.0;
        mat.roughness = 1.0;
        mat.metallic = 0.0;
        mat.ior = 1.33;
        mat.clearcoat = 0.0;
    }

#endif
    if (noHit(hit))
    {
        mat.emissive = getSkybox(ray.direction);
    }
}

float pdfSpecular(float NdotV, float NdotL, float NdotWM, float WOdotWM, float roughness, vec3 wi)
{
#if GGX_MULTISCATTERING != 2

#if GGX_IMPORTANCE_SAMPLING == 1
    return NdotV * D_GGX(NdotWM, roughness) * NdotWM / (4.0 * WOdotWM);
#elif GGX_IMPORTANCE_SAMPLING == 2
    return V_SmithGGXMasking(NdotV, NdotL, roughness) * D_GGX(NdotWM, roughness);
#else
    return NdotV * INV_PI * 0.5;
#endif

#else
    float D = D_GGX(NdotWM, roughness);
    float lambda = SmithLambda(wi, roughness);
    //float singlescatter = V_SmithGGXMasking(NdotV, NdotL, roughness) * D_GGX(NdotWM, roughness);
    float singlescatter = 0.25 * D / max((1.0 + lambda), EPSILON);
    
    float multiscatter = NdotV * INV_PI;

    float albedo = MultiscatteringGGXAlbedo(roughness);
    
    return (albedo * singlescatter + (1.0f - albedo) * multiscatter);
#endif
}

vec3 Fr_GGX(float NdotV, float NdotL, float NdotH, float LdotH, float VdotH, vec3 f0, float roughness, vec3 wi, vec3 wo)
{
    float D = D_GGX(NdotH, roughness);
    vec3  F = F_Schlick(LdotH, f0);
    float V = V_SmithGGXCorrelated(NdotV, NdotL, roughness);

#if GGX_MULTISCATTERING == 1
    if (roughness <= MIN_ROUGHNESS)
        return F * (D * V);

    // https://blog.selfshadow.com/publications/s2017-shading-course/imageworks/s2017_pbs_imageworks_slides_v2.pdf
    float Eavg = EnergyLossAvg(roughness);
    float Ems = EnergyLoss(NdotV, roughness) * EnergyLoss(NdotL, roughness) * INV_PI / Eavg;
    
    #if 0
    vec3 sqrtF0 = sqrt(f0);
    vec3 fIor = (1.0 + sqrtF0) / (1.0 - sqrtF0);
    vec3 Favg = FresnelAvg(1.0 / fIor);
    vec3 Fms = (Favg * Favg * (1.0 - Eavg)) / (1.0 - Favg * Eavg);
    #else
    vec3 Fms = FresnelAvg2(f0);
    #endif
    
    return F * (D * V) + Ems * Fms * NdotV / 2.0;
#elif GGX_MULTISCATTERING == 2
    
    return MultiscatteringEval(wi, wo, roughness);
#else
    return F * (D * V);
#endif
}

vec3 Fr_GGX_Transmission(float NdotV, float NdotL, float NdotH, float LdotH, float VdotH, vec3 f0, float iorV, float iorL, float roughness)
{
    float D = D_GGX(NdotH, roughness);
    //vec3  F = F_Schlick(LdotH, f0);
    float F = FresnelDielectric(LdotH, iorV);
    float V = V_SmithGGXCorrelated(NdotV, NdotL, roughness);
    float denom = iorL * LdotH +  iorV * VdotH;
    
    return 4.0 * f0 * (1.0 - F) * (D * V) * LdotH * VdotH * iorV * iorV / (denom * denom);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    initState(fragCoord, iFrame);
    
    vec2 o = halton(vec2(13, 23) * float(iFrame));
    vec2 pv = (2. * (fragCoord + o - 0.5) - iResolution.xy) / iResolution.y;
    vec2 uv = fragCoord / iResolution.xy;
    
    data.xy = uv;
    
    vec3 ro = vec3(0, 0, 5);
    vec3 lo = vec3(0, 0, 0);
    
    vec4 m = texelFetch(iChannel0, ivec2(0, 0), 0);
    if (iFrame < 2)
        m = vec4(0.59, 0.46, 0, 0);
    
    #ifdef STATIC_CAM
    //m.xy = vec2(0.5, 0.334);
    //m.xy = vec2(0.67, 0.45);
    //m.xy = vec2(0.59, 0.46);
    //m.xy = vec2(0.88, 0.44);
    //m.xy = vec2(0.415, 0.46);
    //m.xy = vec2(0.56, 0.44);
    m.xy = vec2(0.59, 0.46);
    #endif
    
    if (int(fragCoord.x) == 0 && int(fragCoord.y) == 0)
    {
        if (iFrame < 2)
        {
            fragColor = vec4(0.59, 0.46, 0, 0);
        } else
        {
            vec2 mn = iMouse.xy / iResolution.xy;
            fragColor = vec4(m);
            if (iMouse.z > 0.0)
            {
                if (fragColor.zw != vec2(0))
                    fragColor.xy += (mn - m.zw);
                fragColor.zw = mn;
            } else
            {
                fragColor.zw = vec2(0);
            }
        }
        return;
    }
    
    float ax = -m.x * TAU + PI;
    float ay = -m.y * PI + PI * 0.5;
    
    ro.yz *= rot2D(ay);
    ro.xz *= rot2D(ax);
    ro.xz *= rot2D(PI);
    ro += lo;
    
    mat3 cmat = getCameraMatrix(ro, lo);
    
    float fovScale = 4.0;
    
    float dofStrength = DOF_STRENGTH;
    float dofDist = DOF_FOCUS_DISTANCE;
    
    #ifdef DOF_AUTOFOCUS
    Ray dofRay = Ray(ro, cmat[2]);
    HitInfo dofHit;
    Material dofMat;
    
    sceneIntersect(dofRay, dofHit, dofMat);
    
    dofDist = dofHit.t / fovScale;
    #endif
    
    #if DOF_TYPE == 0
    vec2 rc = randomPointInCircle();
    #elif DOF_TYPE == 1
    vec2 rc = randomPointInSquare();
    #elif DOF_TYPE == 2
    vec2 rc = randomPointInPolygon(float(DOF_SIDES));
    #elif DOF_TYPE == 3
    vec2 rc = randomPointInStar(float(DOF_SIDES));
    #elif DOF_TYPE == 4
    vec2 rc = randomPointInHeart();
    #elif DOF_TYPE == 5
    //vec2 rc = randomPointInCresent(-0.5);
    vec2 rc = randomPointInCrescentApprox(-0.5);
    #elif DOF_TYPE == 6
    vec2 rc = randomPointTest();
    #elif DOF_TYPE == 7
    vec2 rc = randomPointInAnnulus(0.5, 1.0);
    #else
    vec2 rc = randomPointInE();
    #endif
    
    rc *= dofStrength * dofDist;
    
    pv -= rc / dofDist;
    ro += cmat * vec3(rc, 0);
    
    vec3 rd = normalize(cmat * vec3(pv, fovScale));
    
    vec3 color = vec3(0);
    vec3 throughput = vec3(1);
    
    Ray ray = Ray(ro, rd);
    HitInfo hit;
    Material mat;
    
    Ray rayNext;
    HitInfo hitNext;
    Material matNext;

    sceneIntersect(ray, hit, mat);
    
    color += mat.emissive;
    
    int i = 0;
    for (; i < BOUNCES; i++)
    {
        if (noHit(hit))
            break;
            
        // Default clearcoat roughness to 0
        #define CLEARCOAT_ROUGHNESS 0.0
        float clearcoatRoughness = max(CLEARCOAT_ROUGHNESS, MIN_ROUGHNESS);
        clearcoatRoughness *= clearcoatRoughness;
        float roughness = max(mat.roughness, MIN_ROUGHNESS);
        roughness *= roughness;
        
        vec3 normal = hit.bumpNormal != vec3(0) ? hit.bumpNormal : hit.normal;
        
        float NdotV = max((dot(hit.normal, -ray.direction)), EPSILON);
        float NBdotV = max((dot(normal, -ray.direction)), EPSILON);
        
        vec3 f0 = mix(vec3(0.04), mat.color, mat.metallic);
        vec3 fresnel3 = F_Schlick(NBdotV, f0);
        float fresnel = (fresnel3.x + fresnel3.y + fresnel3.z) / 3.0;
        
        float clearcoatFresnel = F_Schlick(NdotV, 0.04);
        
        float clearcoatRayPdf = clearcoatFresnel * mat.clearcoat;
        
        // This is wrong but idk yet, sorry devsh v_v
        float specularRayPdf = mix(fresnel, 1.0, mat.metallic);
        float diffuseRayPdf = (1.0 - mat.transmission) * (1.0 - specularRayPdf);
        float transmissionRayPdf = mat.transmission * (1.0 - specularRayPdf);
        
        specularRayPdf *= (1.0 - clearcoatRayPdf);
        diffuseRayPdf *= (1.0 - clearcoatRayPdf);
        transmissionRayPdf *= (1.0 - clearcoatRayPdf);
        
        float totalRayPdf = clearcoatRayPdf + specularRayPdf + transmissionRayPdf + diffuseRayPdf;
        
        bool isClearcoatRay = hash(state) < clearcoatRayPdf / totalRayPdf;
        bool isSpecularRay = !isClearcoatRay && hash(state) < specularRayPdf / totalRayPdf;
        bool isTransmissionRay = !isClearcoatRay && !isSpecularRay && hash(state) < transmissionRayPdf / totalRayPdf;
        
        //isClearcoatRay = false; isSpecularRay = true; isTransmissionRay = false;
        
        if (isClearcoatRay)
            normal = hit.normal;
        
        mat3 tbn = getBasis(normal);
        
        vec3 wo = inverse(tbn) * -ray.direction;
        vec3 wi, wm;
        
        if (isClearcoatRay)
        {
            wi = sampleSpecular(wo, clearcoatRoughness, wm);
            rayNext.direction = tbn * wi;
        } else if (isSpecularRay)
        {
        #if GGX_MULTISCATTERING == 2
            wi = MultiscatteringSample(-wi, wo, roughness);
        #else
            wi = sampleSpecular(wo, roughness, wm);
        #endif
            rayNext.direction = tbn * wi;
        } else if (isTransmissionRay)
        {
            sampleSpecular(wo, roughness, wm);
            wi = -refract(wo, -wm, hit.inside ? mat.ior : 1.0 / mat.ior);
            if (dot(wi, wi) < EPSILON)
                wi = -reflect(wo, wm);
            rayNext.direction = tbn * wi;
        } else {
            rayNext.direction = sampleDiffuse(hit.normal);
        }
        
        rayNext.origin = ray.origin + ray.direction * hit.t + rayNext.direction * 1e-3;
        rayNext.origin += (isTransmissionRay ? -hit.normal : hit.normal) * 1e-3;
        
        sceneIntersect(rayNext, hitNext, matNext);
        
        vec3 halfVector = normalize(-ray.direction + rayNext.direction);
        
        float NdotL = max(dot(normal, rayNext.direction), EPSILON);
        float NdotH = max(dot(normal, halfVector), EPSILON);
        float LdotH = max(dot(rayNext.direction, halfVector), EPSILON);
        float VdotH = max(dot(-ray.direction, halfVector), EPSILON);
        float WOdotWM = max(dot(wo, wm), EPSILON);
        float NdotWM = max(wm.z, EPSILON);
        
        vec3 diffuse, specular;
        
        vec3 reflectance = vec3(0);
        
        if (isClearcoatRay)
        {
            specular = Fr_GGX(NdotV, NdotL, NdotH, LdotH, VdotH, vec3(1), clearcoatRoughness, wi, wo);
            
            float specularPdf = pdfSpecular(NdotV, NdotL, NdotWM, WOdotWM, clearcoatRoughness, wi);
            
            reflectance = throughput * matNext.emissive * specular / specularPdf;
            throughput *= specular / specularPdf;
            
        } else if (isSpecularRay)
        {
            specular = Fr_GGX(NdotV, NdotL, NdotH, LdotH, VdotH, mat.color, roughness, wi, wo);
            
            float specularPdf = pdfSpecular(NdotV, NdotL, NdotWM, WOdotWM, roughness, wi);
            
            reflectance = throughput * matNext.emissive * specular / specularPdf;
            throughput *= specular / specularPdf;
            
        } else if (isTransmissionRay)
        {
            float eta = wi.z > 0.0 ? mat.ior : 1.0 / mat.ior;
            halfVector = normalize(-ray.direction + rayNext.direction * eta);
            NdotL = max(abs(dot(normal, -rayNext.direction)), EPSILON);
            NdotH = max(abs(dot(normal, halfVector)), EPSILON);
            LdotH = max(abs(dot(-rayNext.direction, halfVector)), EPSILON);
            VdotH = max(abs(dot(-ray.direction, halfVector)), EPSILON);
            
            float iorV = hit.inside ? mat.ior : 1.0;
            float iorL = !hit.inside ? mat.ior : 1.0;
            
            specular = Fr_GGX_Transmission(NdotV, NdotL, NdotH, LdotH, VdotH, mat.color, iorV, iorL, roughness);
            
            float specularPdf = pdfSpecular(NdotV, NdotL, NdotH, VdotH, roughness, wi);
            
            reflectance = throughput * matNext.emissive * specular / specularPdf;
            throughput *= specular / specularPdf;
            
        } else {
            vec3 diffuseColor = mat.color;
            #if 0
            diffuse = diffuseColor * Fd_Burley(NdotV, NdotL, LdotH, roughness);
            #else
            diffuse = diffuseColor * Fd_Lambertian();
            #endif
            
            float diffusePdf = pdfDiffuse();
            
            reflectance = throughput * matNext.emissive * diffuse / diffusePdf;
            throughput *= diffuse / diffusePdf;
        }
        
        color += reflectance;
        
        if (luminance(throughput) < 1.0 / 256.0)
            break;
        
        if (noHit(hitNext))
            break;
        
        ray = rayNext;
        hit = hitNext;
        mat = matNext;
    }
    
    vec3 outColor = color;

#ifndef NO_ACCUMULATE
    vec4 prevColor = texelFetch(iChannel0, ivec2(fragCoord), 0);
    
    float blend = iFrame == 0 ? 1.0 : 1.0 / (1.0 + (1.0 / prevColor.a));
    
    #ifndef STATIC_CAM
    if (m.zw != vec2(0))
        blend = 1.0;
    #endif
    
    fragColor = vec4(mix(prevColor.rgb, outColor, blend), blend);
#else
    fragColor = vec4(outColor, 1);
#endif
}


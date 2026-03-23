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

//Traces the scene [thx Stubman]
HitInfo TraceRay(RayDesc ray)
{
    HitInfo sphere_hit; 
    {
        //Set up materials
        vec3 albedo = vec3(1.0, 0.7, 0.3);
        float roughness = gl_FragCoord.x < 0.5 * iResolution.x ? 0.25 : 1.0;

        //Create materials
        Material sphere_material = remap_materials(albedo, roughness);
            
        //Ray cast
        ray_sphere_intersection(ray, vec4(0.0, 2.0, 2.0, 1.0), sphere_material, sphere_hit);
    }
    return sphere_hit;
}   


//Phase function
//Simple diffuse+specular material
vec3 vndf_phase_function(vec3 V_tangent, HitInfo ray, inout vec3 throughput) 
{
    //Sample VNDF
    vec3 H_tangent = sample_ggx_vndf(V_tangent, RandNext2F(), ray.material.alpha);

    //VdotH
    float VdotH = clamp(dot(V_tangent, H_tangent), 0.0, 1.0);

    //Sample fresnel (F0 = 0.04)
    float fresnel = F_SphericalGaussian(VdotH, 0.04);

    //Calculate specular bounce probability
    float fresnel_luma = dot(fresnel, 0.33);
    float albedo_luma = dot(ray.material.albedo, vec3(0.33));
    float total_luma = albedo_luma * (1.0 - fresnel_luma) + fresnel_luma;
    float specular_probablility = fresnel_luma / total_luma;

    if(specular_probablility > RandNextF()) 
    {
        //Calculate new ray direction
        vec3 L = reflect(-V_tangent, H_tangent);

        //Update throughput
        throughput /= specular_probablility; //Probablity
        throughput *= fresnel; //Fresnel

        //Output new direction
        return L;
    } 
    else 
    {
        //Calculate new ray direction (microfacet oriented cosine hemisphere)
        vec3 L = sample_cosine_hemisphere(H_tangent, RandNext2F());

        //Update throughput
        throughput /= 1.0 - specular_probablility; //Probablity
        throughput *= ray.material.albedo; //Albedo      
        throughput *= 1.0 - fresnel; //Fresnel (I know it's not "that" simple, feel free to improve it in your project.)

        //Output new direction
        return L;
    }
}

//Importance sample phase function using random walk algorithm
vec3 ggx_random_walk(vec3 wi, HitInfo ray, inout vec3 throughput) 
{
    //Scattering orders
    int MS_ORDER = gl_FragCoord.y > 0.5 * iResolution.y ? 32 : 1;
    
    //Initialize
    vec3 wr = -wi; //Direction
    float hr = 0.0; //Heightfield
    int i = 0; //Iteration count
    
    while(i <= MS_ORDER)
    {
        //Sample GGX microsurface
        hr = sample_ggx_height(RandNextF(), wr, hr, ray.material.alpha);

        //Did we left the microsurface?
        if(hr > 0.0)
            break;
        else
            i++;
            
        //Sample phase function with new direction and update throughput
        wr = vndf_phase_function(-wr, ray, throughput);

        //NaN fixer no.1
        if(hr != hr || wr.z != wr.z)
            return vec3(0.0, 0.0, 1.0);  
    }

    //NaN fixer no.2. 
    //Just to be 200% sure we don't get any NaNs
    throughput = i > MS_ORDER ? vec3(0.0) : max(throughput, 0.0);

    //Output new direction
    return wr;
}


//Returns shiny ball :P
vec3 ggx_vndf_smith_ms(vec3 N, vec3 V, HitInfo ray)
{
    //Othronormal basis
    mat3 TBN;  
    TBN[0] = normalize(V - N * dot(N, V));
    TBN[1] = cross(N, TBN[0]); 
    TBN[2] = N;
    
    //Rotate (world) view direction to tangent space
    vec3 V_tangent = V * TBN;

    //Accumulator
    vec3 lighting = vec3(0.0);

    for(int i = 0; i < IS_SAMPLE_COUNT; i++)
    {
        //Get sample direction and throughput
        vec3 throughput = vec3(1.0);
        vec3 L_tangent = ggx_random_walk(V_tangent, ray, throughput);

        //Rotate L_tangent to world space
        vec3 L = TBN[0].xyz * L_tangent.x + (TBN[1].xyz * L_tangent.y + (TBN[2].xyz * L_tangent.z));

        //Sample cubemap with new direction
        vec3 sampled_cube = toLinear(textureLod(iChannel1, L, 0.0).xyz);

        //Accumulate the samples
        lighting += sampled_cube * throughput;
          
    }
    lighting /= float(IS_SAMPLE_COUNT);

    //Output
    return lighting;
}


//Scene rendering
vec3 get_scene_color(vec2 frag)
{
    //Clip space position
    vec2 p = (2.0 * gl_FragCoord.xy - iResolution.xy) / iResolution.x;
    
    //Jitter the position for anti-alias effect
    p += RandNext2F() * (2.0 / iResolution.xy);

    //Camera origin
    vec3 camera_origin = vec3(0.0, 2.0, -1.0);
    
    //Camera direction
    vec3 camera_direction = normalize(vec3(p, 1.0));

    //Primary ray data
    RayDesc primaryRay;
    primaryRay.Origin = camera_origin;
    primaryRay.Direction = camera_direction;
    primaryRay.TMin = 0.0;
    primaryRay.TMax = MAX_DISTANCE;

    //Shoot primary ray
    HitInfo rayHit = TraceRay(primaryRay);
    bool hit = rayHit.dist > 0.0;

    //Background
    vec3 color = toLinear(textureLod(iChannel1, primaryRay.Direction, 0.0).xyz);

    //If we hit something, let's calculate all stuff
    if(hit) 
    {
        //Vectors
        vec3 N = rayHit.normal;
        vec3 V = -normalize(primaryRay.Direction);

        //Final lighting
        color = ggx_vndf_smith_ms(N, V, rayHit);
    }
    return color;
}

//Render everything
void mainImage(out vec4 fragColor, in vec2 fragCoord) 
{
    //Initialize RNG
    InitRand(uint(fragCoord.x) + uint(iResolution.x) * (uint(fragCoord.y) + uint(iResolution.y) * uint(iFrame)));

    //Sample the scene
    vec3 color = get_scene_color(fragCoord);

    //Previous frame
    vec3 color_prev = texelFetch(iChannel0, ivec2(fragCoord), 0).xyz;

    //Blend
    color = mix(color_prev, color, 1.0 / float(iFrame + 1));

    //Output to framebuffer
    fragColor = vec4(color, 1.0);
}

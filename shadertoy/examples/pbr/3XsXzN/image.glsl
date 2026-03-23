// The MIT License
// Copyright © 2023 Pascal Gilcher
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#if 0

    New Variant of bounded VNDF sampling that can be used with SmithG2/SmithG1 integration
    
    VNDF Sampling w/ GGX Microfacets has 2 benefits:

        - fewer wasted rays
        - BRDF*cosine/PDF simplifies to G2/G1
        
    There are 3 VNDF samplers:

    1) Heitz "Sampling the GGX Distribution of Visible Normals"
    
    2) Dupuy "Sampling Visible GGX Normals with Spherical Caps"
    
        + less ALU than Heitz
    
    3) Eto & Tokuyoshi "Bounded VNDF Sampling for Smith–GGX Reflections"
    
        + faster convergence
        - have to use full BRDF*cosine/PDF due to different PDF
    
    ----------------------------------------------------------------------------    
    
    I extracted the difference between the PDFs of method 3 vs the others
    and applied it to the sampler. Converges to the same result.    
    
    With this method, you get the numerical stability and performance of 1 and 2
    combined with the fast convergence of 3. 
    
    ----------------------------------------------------------------------------  
/*  
    How it works:
    
       RDF*cosine/PDF resolve into G2/G1 _somehow_ in Heitz/Dupuy method,  we just need 
       to figure out what changed in the PDF from 2 to 3 and accomodate for that.
       
       Loking at listing 2 in their paper, the clue is in here:

           ...
A               return ndf / (2.0f * (k * i.z + t));
           }
           // Numerically stable form of the previous PDF for i.z < 0
B          return ndf * ( t - i . z ) / (2.0 f * len2 ) ; // = Eq. 7 * || dm/do ||
           ...

       Hold up. If I read the comment for line B right, it's the same as A, just restructured?
       Since k is 1.0 for i.z < 0, this branch is just for numerical stability. We COULD write it as:

               pdf = ndf / (2.0f * (k * i.z + t))
               
       I then realized that Method 2 from Dupuy is identical to this method, except the scaling factor
       k is ALWAYS 1. So...
       
       PDF of Dupuy:              ndf / (2.0f * (1.0 * i.z + t))
       PDF of Eto/Tokuyoshi:      ndf / (2.0f * (k   * i.z + t)) 
       
       So...
       
       let A = ndf / (2.0f * (1.0 * i.z + t)) 
           B = ndf / (2.0f * (k * i.z + t)) 
       
            BRDF * cosine / PDF
            
       =    G2/G1       
       =    A * [G2/G1 without A]
       =    correction_term * B * [G2/G1 without A] 
       =    correction_term * B * A/A * [G2/G1 without A]
       =    correction_term * B/A * [G2/G1]
       
       !
       =    G2/G1
                                                
       =>   correction_term = A/B   
       
           ndf / (2.0f * (1.0 * i.z + t))    
       =   ---------------------------------
            ndf / (2.0f * (k * i.z + t)) 
            
         
                   k * i.z + t
       =          -----------
                     i.z + t        
         
       Which we need to multiply each sample with.    
*/
#endif

//I've stolen parts of this framework here from LVutner

#define DISABLE_CORRECTION_TERM 0 //disable my pdf ratio correction
#define SAMPLES 4u

float map(vec3 p)
{
    return distance(p, vec3(0,0,4)) - 1.0;
}

vec3 get_normal(vec3 p)
{
    vec2 e = vec2(1.0,-1.0)*0.5773*0.0005;
    return normalize(e.xyy*map(p + e.xyy) + 
					 e.yyx*map(p + e.yyx) + 
					 e.yxy*map(p + e.yxy) + 
					 e.xxx*map(p + e.xxx));
}

struct Ray
{
    vec3 origin;
    vec3 dir;
    float t;
};

Ray camera_ray(vec2 uv, float fov)
{
    uv = uv * 2.0 - 1.0;
    uv.x *= iResolution.x / iResolution.y;    
    uv *= tan(radians(fov) * 0.5);
    
    Ray ray;
    ray.origin = vec3(0);
    ray.dir = normalize(vec3(uv, 1));
    return ray;    
}


void trace_scene(inout Ray ray)
{
    ray.t = 0.0;
    float d = 1.0;
    for(int i = 0; i < 128 && d > 1e-4; i++)
    {
        d = map(ray.origin + ray.dir * ray.t);
        ray.t += d;
    }
}

vec3 get_incident_light(vec3 dir)
{
    vec3 L = textureLod(iChannel1, dir, 0.0).rgb;
    L = to_linear(L);
    //L = vec3(dot(L, vec3(0.3333)));
    return L;
}

float lambda_smith(float ndotx, float alpha)
{    
    float alpha_sqr = alpha * alpha;
    float ndotx_sqr = ndotx * ndotx;
    return (-1.0 + sqrt(alpha_sqr * (1.0 - ndotx_sqr) / ndotx_sqr + 1.0)) * 0.5;
}

float smith_G1(float ndotv, float alpha)
{
	float lambda_v = lambda_smith(ndotv, alpha);
	return 1.0 / (1.0 + lambda_v);
}

float smith_G2(float ndotl, float ndotv, float alpha) //height correlated
{
	float lambda_v = lambda_smith(ndotv, alpha);
	float lambda_l = lambda_smith(ndotl, alpha);
	return 1.0 / (1.0 + lambda_v + lambda_l);
}

float fresnel_schlick(float cos_theta, float F0)
{
    float f = saturate(1.0 - cos_theta);
    float f2 = f * f;   
    return mad(f2 * f2 * f, 1.0 - F0, F0);
}
//====================================================================
//====================================================================
//
//     Original VNDF
//
//====================================================================
//====================================================================

// Input Ve: view direction
// Input alpha_x, alpha_y: roughness parameters
// Input U1, U2: uniform random numbers
// Output Ne: normal sampled with PDF D_Ve(Ne) = G1(Ve) * max(0, dot(Ve, Ne)) * D(Ne) / Ve.z
vec3 sampleGGXVNDF(vec3 Ve, float alpha_x, float alpha_y, float U1, float U2)
{
	// Section 3.2: transforming the view direction to the hemisphere configuration
	vec3 Vh = normalize(vec3(alpha_x * Ve.x, alpha_y * Ve.y, Ve.z));
	// Section 4.1: orthonormal basis (with special case if cross product is zero)
	float lensq = Vh.x * Vh.x + Vh.y * Vh.y;
	vec3 T1 = lensq > 0.0 ? vec3(-Vh.y, Vh.x, 0) * inversesqrt(lensq) : vec3(1,0,0);
	vec3 T2 = cross(Vh, T1);
	// Section 4.2: parameterization of the projected area
	float r = sqrt(U1);	
	float phi = TAU * U2;	
	float t1 = r * cos(phi);
	float t2 = r * sin(phi);
	float s = 0.5 * (1.0 + Vh.z);
	t2 = (1.0 - s)*sqrt(1.0 - t1*t1) + s*t2;
	// Section 4.3: reprojection onto hemisphere
	vec3 Nh = t1*T1 + t2*T2 + sqrt(max(0.0, 1.0 - t1*t1 - t2*t2))*Vh;
	// Section 3.4: transforming the normal back to the ellipsoid configuration
	vec3 Ne = normalize(vec3(alpha_x * Nh.x, alpha_y * Nh.y, max(0.0, Nh.z)));	
	return Ne;
}

vec3 canonical_vndf_heitz(vec3 n, vec3 wo, uvec2 seed)
{
    vec3 Lo = vec3(0);    
    vec3 Le = vec3(0);
    
    float alpha = iMouse.x / iResolution.x;   
    
    mat3 TBN;  
    TBN[0] = normalize(wo - n * dot(n, wo));
    TBN[1] = cross(n, TBN[0]); 
    TBN[2] = n;
    
    vec3 V_tangent = -wo * TBN;
    
    float NdotV = saturate(V_tangent.z);
    float G1 = smith_G1(NdotV, alpha);    
    
    const uint N = SAMPLES;    
    
    for(uint i = 0u; i < N; i++)
    {
        vec2 u = r2(i, seed);          
        vec3 H_tangent = sampleGGXVNDF(V_tangent, alpha, alpha, u.x, u.y);            
        vec3 L_tangent = reflect(-V_tangent, H_tangent);
        float VdotH = dot(V_tangent, H_tangent);         
        float NdotL = saturate(L_tangent.z);

        if(L_tangent.z <= 0.0) continue;              

        vec3 L = TBN * L_tangent;
        vec3 Li = get_incident_light(L);  
        
        float F = fresnel_schlick(VdotH, 0.04);        
        float G2 = smith_G2(NdotL, NdotV, alpha);        
        
        Lo += Li * F * G2/G1;         
    }

    Lo /= float(N);      
    return Lo;
}

//====================================================================
//====================================================================
//
//     New Bounded Spherical Cap Method w/ my correction term
//
//====================================================================
//====================================================================

vec3 SphericalCapBoundedWithPDFRatio(vec2 u, vec3 wi, vec2 alpha, out float pdf_ratio)
{
    // warp to the hemisphere configuration
    
    //PGilcher: save the length t here for pdf ratio
    vec3 wiStd = vec3(wi.xy * alpha, wi.z);
    float t = length(wiStd);
    wiStd /= t;   
    
    // sample a spherical cap in (-wi.z, 1]
    float phi = (2.0f * u.x - 1.0f) * PI;
    
    float a = saturate(min( alpha.x, alpha.y)); // Eq. 6
    float s = 1.0f + length(wi.xy); // Omit sgn for a <=1
    float a2 = a * a; 
    float s2 = s * s;
    float k = (1.0 - a2) * s2 / (s2 + a2 * wi.z * wi.z); 

    float b = wiStd.z;
    b = wi.z > 0.0 ? k * b : b;

   //PGilcher: compute ratio of unchanged pdf to actual pdf (ndf/2 cancels out)
   //Dupuy's method is identical to this except that "k" is always 1, so
   //we extract the differences of the PDFs (Listing 2 in the paper)
    pdf_ratio = (k * wi.z + t) / (wi.z + t);    
    
    float z = mad((1.0f - u.y), (1.0f + b), -b);
    float sinTheta = sqrt(clamp(1.0f - z * z, 0.0f, 1.0f));
    float x = sinTheta * cos(phi);
    float y = sinTheta * sin(phi);
    vec3 c = vec3(x, y, z);
    // compute halfway direction as standard normal
    vec3 wmStd = c + wiStd;
    // warp back to the ellipsoid configuration
    vec3 wm = normalize(vec3(wmStd.xy * alpha, wmStd.z));
    // return final normal
    return wm;
}

vec3 spherical_cap_new_vndf(vec3 n, vec3 wo, uvec2 seed)
{
    //return n;
    vec3 Lo = vec3(0);    
    vec3 Le = vec3(0);
    
    float alpha = iMouse.x / iResolution.x;   
    
    mat3 TBN;  
    TBN[0] = normalize(wo - n * dot(n, wo));
    TBN[1] = cross(n, TBN[0]); 
    TBN[2] = n;
    
    vec3 V_tangent = -wo * TBN;
    
    float NdotV = saturate(V_tangent.z);
    float G1 = smith_G1(NdotV, alpha);    
    
    const uint N = SAMPLES;    
    int accepted_samples = 0;
    
    for(uint i = 0u; i < N; i++)
    {
        vec2 u = r2(i, seed); 
        float pdf_ratio;
        vec3 H_tangent = SphericalCapBoundedWithPDFRatio(u.yx, V_tangent, vec2(alpha), pdf_ratio);//sampleGGXVNDF(V_tangent, alpha, alpha, u.x, u.y);            
        
        vec3 L_tangent = reflect(-V_tangent, H_tangent);
        float VdotH = dot(V_tangent, H_tangent);         
        float NdotL = saturate(L_tangent.z);

        if(L_tangent.z <= 0.0) continue;        
        accepted_samples++;        

        vec3 L = TBN * L_tangent;
        vec3 Li = get_incident_light(L);  
        
        float F = fresnel_schlick(VdotH, 0.04);        
        float G2 = smith_G2(NdotL, NdotV, alpha); 
        
#if DISABLE_CORRECTION_TERM
        pdf_ratio = 1.0;
#endif
        
        Lo += Li * F * G2/G1 * pdf_ratio;         
    }    

    Lo /= float(N); 
    return Lo;
}

//====================================================================

void mainImage( out vec4 o, in vec2 vpos )
{
    vec2 uv = vpos/iResolution.xy;    
    Ray camera = camera_ray(uv, 40.0);
    
    trace_scene(camera);
    vec3 hit = camera.origin + camera.dir * camera.t;
    vec3 normal = get_normal(hit);
    
    o = texture(iChannel1, camera.dir);
    if(camera.t > 10.0 || dot(normal, camera.dir) > 0.0) return;
    
    uvec2 seed;
    seed = uvec2(texelFetch(iChannel0, ivec2(vpos) & 1023, 0).xy * exp2(32.0)); 
    
    if(uv.x > 0.5)
    {
        o.rgb = spherical_cap_new_vndf(normal, camera.dir, seed); 
    }
    else 
    {
        o.rgb = canonical_vndf_heitz(normal, camera.dir, seed); 
    }    
    
    o.rgb *= 30.0;
    o.rgb = o.rgb * ACESInputMat;
    o.rgb = RRTAndODTFit(o.rgb);
    o.rgb = o.rgb * ACESOutputMat;
    o.rgb = saturate(o.rgb);

    o.rgb = from_linear(o.rgb);    
}

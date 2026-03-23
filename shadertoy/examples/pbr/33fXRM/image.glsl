/**
 * -----------------------------------------------------------
 * - SDF Outline Comparison
 * - Created by Steven Sell (ssell) / 2017
 * - License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
 * - https://www.shadertoy.com/view/4lfyR2
 * -----------------------------------------------------------
 * 
 * Comparison of four different approaches for SDF outlining.
 * Use the mouse to drag the screen dividers.
 *
 *     Upper Left:  SDF Near-Miss
 *     Upper Right: SDF Offset Differences
 *     Lower Left:  Edge Detection
 *     Lower Right: Surface ID Differences
 *
 * -----------------------------------------------------------
 * - SDF Near-Miss
 * - Outline_NearMiss()
 * -----------------------------------------------------------
 * 
 * The outline is calculated based off of near-misses during raymarching,
 * where the ray comes within a threshold of the scene geometry but does
 * not make a direct hit.
 *
 * The outline/border thickness is calculated in world-units and thus will
 * vary in size based on depth. 
 *
 * This approach does not produce internal outlines, but that may be desireable.
 *
 * Pros:
 *
 *     - Cheap, minor modification to raymarching loop to keep track of nearest passes.
 *     - No additional scene sampling.
 *     - Only approach with smooth external outline edges.
 *
 * Cons:
 *
 *     - Have to modify raymarch routine.
 *     - Only approach without internal edge outlining.
 *     - Jagged internal outline.
 *
 * -----------------------------------------------------------
 * - SDF Offset Differences
 * - Outline_OffsetDifference()
 * -----------------------------------------------------------
 *
 * Calculates the difference between a raymarch sample and two offset samples.
 * If the difference in depth between the samples is within a threshold, then
 * it is part of an outline.
 *
 * This approach requires an additional two samples of the scene, which may
 * be expensive depending on the shader. It is also has controls for outline 
 * appearance in both UV-space (pixel may be used, but UV produces a smoother 
 * result) and world-space.
 *
 * Pros:
 *
 *     - Partial internal edge outlining.
 *     - Some internal outline edges are smooth.
 *     - Requires no modification of existing raymarch routine.
 *
 * Cons:
 *
 *     - Potentially trickier to calibrate for a given scene
 *     - Requires two additional scene marches.
 *
 * -----------------------------------------------------------
 * - SDF Edge Detection
 * - Outline_EdgeDetection()
 * -----------------------------------------------------------
 *
 * Detects SDF edges by keeping track of previous SDF values. If the ray
 * is moving away from a surface and it passed within a threshold of that
 * surface, then it is an outline.
 *
 * The controls for this outline are solely in world-space units (edge threshold).
 *
 * Both this approach and Offset Difference produce a partial internal outlining
 * that give a stroke/pen appearance that may be desired.
 *
 * Pros:
 *
 *     - Partial internal edge outlining.
 *     - Cheap, no additional samples or calculations outside of the march.
 *
 * Cons:
 *
 *     - Have to modify raymarch routine.
 *     - Jagged outline.
 *
 * -----------------------------------------------------------
 * - Surface ID Difference
 * - Outline_SurfaceIDDifference()
 * -----------------------------------------------------------
 *
 * The only approach that is not based on SDF values but instead on surface/material IDs. 
 * While defining the scene, must provide each surface/subset with a unique ID. During
 * the outlining, offsets into the scene are sampled. If the offsets have different IDs
 * then an outline edge is found.
 *
 * While this does not require modification to the raymarch itself, and the outline 
 * calculation is similar to SDF Offset Differences, it does potentially require a lot
 * of changes to the scene definition. But if you are already defining your scene with
 * material/surface IDs then no work may need to be done.
 *
 * Pros:
 *
 *     - Nearly full control over edge definitions.
 *     - Provides full external and internal outlining.
 *
 * Cons:
 *
 *     - Have to manually define surfaces.
 *     - Jagged edges.
 * 
 * -----------------------------------------------------------
 * - References
 * -----------------------------------------------------------
 * 
 * While I know that these different approaches are used in other ShaderToys,
 * the only one that was directly referenced/sourced was:
 *
 *     'Bender' - iq
 *      https://www.shadertoy.com/view/4slSWf
 *
 *      I initially thought that 'SDF Offset Differences' was being used in this shader,
 *      but after experimentation I saw it was completely different approach which
 *      is  called 'Surface ID Differences' in this shader for lack of a proper name.
 */

#define NearClip          0.0
#define Epsilon           0.01
#define FarClip           10.0
#define MaxSteps          100
#define PI                3.14159265
#define NearMissThreshold 0.045     // Used in SDF Near-Miss. World-Space.
#define EdgeThresold      0.03      // Used in SDF Edge Detection. World-Space.
#define UVOffset          0.003     // Used in SDF Offset Differences and Surface ID Differences. UV-Space.

      vec3 CamOrigin       = vec3(0.0);
const vec3 CamLookAt       = vec3(0.0, 1.05, 0.0);
const vec3 BackgroundColor = vec3(0.0, 0.335, 0.582);
const vec3 SunDir          = normalize(vec3(0.5, 2.5, 1.25));
const vec3 SunColor        = vec3(1.0, 1.0, 0.7);
const vec3 SkyDir          = normalize(vec3(0.0, 1.0, 0.0));
const vec3 SkyColor        = vec3(0.0, 0.0, 1.0);
const vec3 AmbDir          = normalize(SunDir * vec3(-1.0, 0.0, -1.0));
const vec3 AmbColor        = vec3(1.0, 1.0, 1.0);

//------------------------------------------------------------------------------------------
// Ray / Camera
//------------------------------------------------------------------------------------------

struct Ray
{
	vec3 o;
    vec3 d;
};

Ray Ray_LookAt(in vec2 uv, in vec3 o, in vec3 d)
{
    vec3 forward = normalize(d - o);
    vec3 right   = normalize(cross(forward, vec3(0.0, 1.0, 0.0)));
    vec3 up      = normalize(cross(right, forward));

    uv    = (uv * 2.0) - 1.0;
    uv.x *= (iResolution.x / iResolution.y);

    Ray ray;
    ray.o = o;
    ray.d = normalize((uv.x * right) + (uv.y * up) + (forward * 2.0));

    return ray;
}

//------------------------------------------------------------------------
// Scene
//------------------------------------------------------------------------

vec3  RotX(in vec3 p, float a)        { float s = sin(a); float c = cos(a); return vec3(p.x, (c * p.y) - (s * p.z), (s * p.y) + (c * p.z)); }
vec3  Repeat(vec3 p, vec3 c)          { return mod(p, c) - (0.5 * c); }
float smin(float a, float b, float k) { float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0); return mix(b, a, h) - k*h*(1.0 - h); }
float Box(vec3 p, vec3 b)             { vec3 d = abs(p) - b; return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0)); }
float Sphere(vec3 p, float r)         { return length(p) - r; }
float Cylinder(vec3 p, vec2 h)        { vec2 d = abs(vec2(length(p.xz),p.y)) - h; return min(max(d.x,d.y),0.0) + length(max(d,0.0)); }
vec2  U(vec2 a, vec2 b)               { return (a.x < b.x) ? a : b; }
vec2  S(vec2 d2, vec2  d1 )           { return (-d1.x>d2.x)?-d1:d2; }

/**
 * Returns (SDF value, Surface ID)
 */
vec2 ShaderBall(vec3 pos)
{
    vec3 spos = pos - vec3(0.0, 1.5, 0.0);
    
    vec2 ts   = vec2(max(Sphere(spos, 1.0), -Sphere(spos, 0.8)), 9.0);                // Hollow top sphere
    vec2 tsi  = vec2(Sphere(spos, 0.725), 2.0);                                       // Inner sphere core
    vec2 tsc  = vec2(Sphere(spos - vec3(0.0, 0.4, 0.8), 0.55), 3.0);                  // Cut into side of top sphere
    vec2 rc   = vec2(Box(RotX(spos, PI * 0.15), vec3(2.0, 0.05, 2.0)), 4.0);          // Ring cut into top sphere
    
    vec2 st   = vec2(Cylinder(pos - vec3(0.0, 0.1, 0.0), vec2(mix(0.8, 0.3, clamp(pos.y - 0.125, 0.0, 1.0)), 0.2)), 5.0);  // Stand wide base      
    vec2 stc  = vec2(Cylinder(Repeat(pos, vec3(0.5, 0.0, 0.5)), vec2(0.125, 1.0)), 6.0);                                   // Stand ridge cuts
    vec2 stm  = vec2(Cylinder(pos - vec3(0.0, 0.35, 0.0), vec2(0.5, 0.35)), 5.0); // Thinner stand middle
    
    st   = S(st, stc);
    st.x = smin(st.x, stm.x, 0.2);                         
    
    vec2 b    = vec2(Cylinder(pos - vec3(0.0, 0.025, 0.0), vec2(1.0, 0.025)), 8.0);    // Base
       
    vec2 result = S(ts, tsc);
         result = S(result, rc);
         result = U(result, tsi);
         result = U(result, st);
         result = U(result, b);
    
    return result;
}

/*float ShaderBall(vec3 pos)   // Version of shader ball that only returns SDF value, no IDs
{
    vec3  spos = pos - vec3(0.0, 1.5, 0.0);
    float ts   = max(Sphere(spos, 1.0), -Sphere(spos, 0.8));                // Hollow top sphere
    float tsi  = Sphere(spos, 0.725);                                       // Inner sphere core
    float tsc  = Sphere(spos - vec3(0.0, 0.4, 0.8), 0.55);                  // Cut into side of top sphere
    float rc   = Box(RotX(spos, PI * 0.15), vec3(2.0, 0.05, 2.0));          // Ring cut into top sphere
    
    float st   = Cylinder(pos - vec3(0.0, 0.1, 0.0), vec2(mix(0.8, 0.3, clamp(pos.y - 0.125, 0.0, 1.0)), 0.2));  // Stand wide base      
    float stc  = Cylinder(Repeat(pos, vec3(0.5, 0.0, 0.5)), vec2(0.125, 1.0));                                   // Stand ridge cuts
          st   = max(st, -stc);
          st   = smin(st, Cylinder(pos - vec3(0.0, 0.3, 0.0), vec2(0.5, 0.3)), 0.2);                             // Thinner stand middle
    
    float b    = Cylinder(pos - vec3(0.0, 0.025, 0.0), vec2(1.0, 0.025));    // Base
               
    float result = min(FarClip, max(ts, -tsc));
          result = max(result, -rc);
          result = min(result, tsi);
          result = smin(result, st, 0.1);
          result = min(result, b);
    
    return result;
}*/

vec2 Scene(vec3 pos)
{
	return vec2(ShaderBall(pos));
}

/**
 * Modified raymarch that supports all of the outline approaches.
 * Returns (depth, nearest pass, edge, id).
 */
vec4 RayMarch(in Ray ray)
{
    float depth   = NearClip;
    float nearest = FarClip;          // Keeps track of nearest pass for SDF Near-Miss outline
    float edge    = 0.0;              // Keeps track of if edge for SDF Edge outline
    float lastSDF = FarClip;          // Keeps track of last SDF value for SDF Edge outline
    
    for(int i = 0; i < MaxSteps; ++i)
    {
    	vec3 pos = ray.o + (ray.d * depth);
        vec2 sdf = Scene(pos);
        
        nearest = min(sdf.x, nearest);
        
        if((lastSDF < EdgeThresold) && (sdf.x > lastSDF))
        {
            edge = 1.0;
        }
        
        if(sdf.x < Epsilon)
        {
            return vec4(clamp(depth, NearClip, FarClip), nearest, edge, sdf.y);
        }
        
        depth  += sdf.x * 0.35;        // Note: Modifying the '* 0.35' affects the outlines in subtle ways.
        lastSDF = sdf.x;
    }
    
    return vec4(FarClip, nearest, edge, 0.0);
}

vec3 SceneNormal(in vec3 pos, in float depth)
{
    vec2 eps = vec2(0.001 * depth, 0.0);
    return normalize(vec3(Scene(pos + eps.xyy).x - Scene(pos - eps.xyy).x,
                          Scene(pos + eps.yxy).x - Scene(pos - eps.yxy).x,
                          Scene(pos + eps.yyx).x - Scene(pos - eps.yyx).x));
}

//------------------------------------------------------------------------
// Outline UL - SDF Near Miss
//------------------------------------------------------------------------

float Outline_NearMiss(in vec4 march)
{
    float a = step(FarClip, march.x);                        // a == 1.0 if the depth >= FarClip, aka a miss
    float b = clamp(march.y / NearMissThreshold, 0.0, 1.0);  // denominator is the border width in world units
    
    return (1.0 - pow(b, 8.0)) * a;                          // pow value controls edge darkness and smooth fade
}

//------------------------------------------------------------------------
// Outline UR - SDF Offset Difference
//------------------------------------------------------------------------

float Outline_OffsetDifference(in vec2 uv, float depth)
{
    // 0.003 is the offset size, and thus outline thickness, in uv
    vec2 offset = vec2(UVOffset, 0.0);              
    
    vec4 marchA = RayMarch(Ray_LookAt(uv + offset.xy, CamOrigin, CamLookAt));
    vec4 marchB = RayMarch(Ray_LookAt(uv - offset.yx, CamOrigin, CamLookAt));
    
    // 0.07 is the depth threshold is world units, and thus is dependent on scene geometry for a proper value.
    float diff = clamp(max(abs(depth - marchA.x), abs(depth - marchB.x)) / 0.07, 0.0, 1.0);
    
    // 0.6 is a control value for outline stroke thickness, and 8.0 is stroke strength.
    return 1.0 - smoothstep(0.6, -0.001, pow(diff, 8.0));
}

//------------------------------------------------------------------------
// Outline LL - Edge Detection
//------------------------------------------------------------------------

float Outline_EdgeDetection(in vec4 march)
{
    return march.z;
}

//------------------------------------------------------------------------
// Outline LR - Surface ID Difference
//------------------------------------------------------------------------

float Outline_SurfaceIDDifference(in vec2 uv, float id)
{
    vec2 offset = vec2(0.004, 0.0);
    
    float idA = RayMarch(Ray_LookAt(uv + offset.xy, CamOrigin, CamLookAt)).w;
    float idB = RayMarch(Ray_LookAt(uv - offset.yx, CamOrigin, CamLookAt)).w;
    
    float e = clamp(max(abs(id - idA), abs(id - idB)), 0.0, 1.0);
                    
    return e;
}

//------------------------------------------------------------------------
// Render
//------------------------------------------------------------------------

vec3 Lighting(in vec3 albedo, in vec3 norm, in vec3 rd)
{
	float shadow = 1.0;
    float direct = max(0.1, dot(norm, SunDir));
    
    vec3 sunLight  = SunColor * direct * 1.5 * shadow;
    vec3 skyLight  = SkyColor * clamp(0.5 + (0.5 * norm.y), 0.0, 1.0) * 0.1;
    vec3 ambLight  = AmbColor * clamp(dot(norm, AmbDir), 0.0, 1.0) * 0.3;
  	vec3 diffLight = (sunLight + skyLight + ambLight) * albedo;
    
    vec3 reflVec   = reflect(-SunDir, norm);
    float specIntens = pow(max(0.0, dot(rd, -reflVec)), 16.0);
    vec3 specLight = specIntens * vec3(0.35) * shadow;
    
    return (diffLight + specLight);
}

vec4 Render(in Ray ray, in vec2 fragCoord, in vec2 uv, int section)
{
	vec4 color = vec4(BackgroundColor, 0.0);
    vec4 march = RayMarch(ray);
    
    if(march.x < FarClip)
    {
        vec3 pos  = ray.o + (ray.d * march.x);
        vec3 norm = SceneNormal(pos, march.x);
        
       	color.rgb = (int(march.w) == 2) ? vec3(1.0, 0.184314, 0.0309804) : vec3(0.9);
        color.rgb = Lighting(color.rgb, norm, ray.d);
        
        color.a = 1.0;
    }
    
    if(section == 1) { color.rgb = mix(color.rgb, vec3(0.0), Outline_NearMiss(march)); }
    if(section == 2) { color.rgb = mix(color.rgb, vec3(0.0), Outline_OffsetDifference(uv, march.x)); }
    if(section == 3) { color.rgb = mix(color.rgb, vec3(0.0), Outline_EdgeDetection(march)); }
    if(section == 4) { color.rgb = mix(color.rgb, vec3(0.0), Outline_SurfaceIDDifference(uv, march.w)); }
    
    return color;
}

//------------------------------------------------------------------------
// Main
//------------------------------------------------------------------------

vec3 OrbitAround(vec3 origin, float radius, float rate)
{
    float time = iTime - 4.5f;
  	return vec3((origin.x + (radius * cos(time * rate))), (origin.y), (origin.z + (radius * sin(time * rate))));
}

int ScreenSection(in vec2 fragCoord)
{
    vec2 mouse = iMouse.xy;
    
    if(mouse.xy == vec2(0.0))
    {
        mouse.xy = iResolution.xy * 0.5;
    }
    
    vec2 diff = fragCoord - mouse.xy;
    
    if(abs(fragCoord.y - mouse.y) < 1.0 || abs(fragCoord.x - mouse.x) < 1.0) { return 0; }
    if(diff.x < 0.0 && diff.y > 0.0) { return 1; }
    if(diff.x > 0.0 && diff.y > 0.0) { return 2; }
    if(diff.x < 0.0 && diff.y < 0.0) { return 3; }
    
    return 4;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    CamOrigin = OrbitAround(vec3(0.0, 2.0, 0.0), 3.5, -0.5);
    
    vec2 uv = (fragCoord / iResolution.xy);
    Ray ray = Ray_LookAt(uv, CamOrigin, CamLookAt);
    
    int section = ScreenSection(fragCoord);
    
    vec4 color = Render(ray, fragCoord, uv, section);
    
    if(section == 0)
    {
        color.rgb *= max(0.65, color.a);
    }
    
    fragColor = vec4(pow(color.rgb, vec3(1.0 / 2.2)), 1.0);
}

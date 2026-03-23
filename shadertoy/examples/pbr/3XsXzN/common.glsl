#define PI   3.14159
#define TAU (PI * 2.0)
#define mad(a,b,c) ((a)*(b)+(c))


vec3 uniform_sample_sphere(vec2 u)
{
    vec3 dir;
    dir.x = cos(u.x * TAU);
    dir.y = sin(u.x * TAU);      
    dir.z = u.y * 2.0 - 1.0; 
    dir.xy *= sqrt(1.0 - dir.z * dir.z);
    return dir;
}

vec3 ray_cosine(vec2 u, vec3 n)
{
    return normalize(uniform_sample_sphere(u) + n);
}

vec3 ray_uniform(vec2 u, vec3 n)
{
    vec3 dir = uniform_sample_sphere(u);
    dir = dot(dir, n) < 0.0 ? -dir : dir;
    return normalize(dir + n * 0.01);
}

vec2 r2(in uint idx, in uvec2 useed)
{
    uvec2 phi = uvec2(3242174889u, 2447445413u);    
    uvec2 p = phi * idx + useed;  
    return vec2(p) * exp2(-32.0);  
}

float saturate(float x){return clamp(x, 0.0, 1.0);}
vec2 saturate(vec2 x){return clamp(x, 0.0, 1.0);}
vec3 saturate(vec3 x){return clamp(x, 0.0, 1.0);}
vec4 saturate(vec4 x){return clamp(x, 0.0, 1.0);}

float pow2(float x)
{
    return x * x;
}

vec3 to_linear(vec3 sRGB)
{
    bvec3 cutoff = lessThan(sRGB, vec3(0.04045));
    vec3 higher = pow((sRGB + vec3(0.055)) / vec3(1.055), vec3(2.4));
    vec3 lower = sRGB / vec3(12.92);

    return mix(higher, lower, cutoff);
}

//Linear to sRGB
vec3 from_linear(vec3 linearRGB)
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




#define N_SPHERES 666
#define MIN_RADIUS 0.005
#define PI 3.14159265359

int seed = 93726;
int randInt() { seed = seed*0x343fd + 0x269ec3; return (seed>>16)&32767; }
float frand() { return float(randInt())/32767.0; }

void srand( ivec2 p, int frame ) {
    int n = frame;
    n = (n<<13)^n; n = n*(n*n*15731+789221)+1376312589; 
    n += p.y;
    n = (n<<13)^n; n = n*(n*n*15731+789221)+1376312589;
    n += p.x;
    n = (n<<13)^n; n = n*(n*n*15731+789221)+1376312589;
    seed = n;
}

vec3 randomOnSphere( void ) {
    float theta = (6.283185 / 32767.0) * float(randInt());
    float u = (2.0 / 32767.0) * float(randInt()) - 1.0;
    return vec3(sqrt(max(0.0, 1.0 - u * u)) * vec2(cos(theta), sin(theta)), u);
}


float hash(vec2 p) {
 return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);   
}


float smin(float a, float b, float k) 
{
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h*h*k*0.25;
}


vec3 erot(vec3 p, vec3 ax, float ro) {
    return mix(dot(p,ax)*ax,p,cos(ro))+sin(ro)*cross(ax,p);
}

//https://www.shadertoy.com/view/3lGcWt
float scene(vec3 pp) {
    vec3 p = pp.zxy;
    // early skip if outside
    if (length(p) > 3.0) {
        return length(p)-2.8;
    }
    //neural networks can be really compact... when they want to be
    vec4 f0_0=sin(p.y*vec4(.00,.00,.00,.01)+p.z*vec4(1.20,-.11,-.05,-3.66)+p.x*vec4(-2.55,.14,-4.41,-.07)+vec4(-3.04,-3.15,-1.75,-4.00));
    vec4 f0_1=sin(p.y*vec4(-.00,-.00,-2.96,-.00)+p.z*vec4(2.84,-.30,-1.07,-2.13)+p.x*vec4(.10,-.38,-.75,-.36)+vec4(-.49,3.12,1.50,3.14));
    vec4 f0_2=sin(p.y*vec4(2.96,.00,-.00,.00)+p.z*vec4(-1.08,.00,-1.10,-.47)+p.x*vec4(-.76,.00,1.15,-.15)+vec4(-4.79,-1.57,-2.81,-3.25));
    vec4 f0_3=sin(p.y*vec4(-.00,-.01,.00,.00)+p.z*vec4(2.89,3.26,2.06,.47)+p.x*vec4(2.78,3.55,-2.21,-3.80)+vec4(4.83,2.15,1.87,-2.77));
    vec4 f1_0=sin(mat4(.10,3.36,-1.58,.75,.19,1.62,-.59,.23,-.26,.84,-.26,-.33,-.21,-.13,.07,-.32)*f0_0+
        mat4(-.46,-2.33,.84,-.20,-1.29,-1.43,.93,-1.44,-.62,-.91,-.46,-1.05,-.21,1.57,1.21,.60)*f0_1+
        mat4(-.62,-.92,-.45,-1.06,.03,.19,.10,-.54,.08,-.27,-.26,-.05,-.22,.86,-.40,-.02)*f0_2+
        mat4(-.22,.02,.20,.08,.56,.05,-.24,.70,.46,.51,1.51,.98,-.82,-1.18,.37,-.84)*f0_3+
        vec4(.72,.15,-1.14,2.07))/1.0+f0_0;
    vec4 f1_1=sin(mat4(-.64,1.09,-.42,.08,.85,.28,-.17,-.14,-1.07,-.40,-.00,.02,-.44,-.54,-.36,.03)*f0_0+
        mat4(1.26,.21,-.40,.05,-1.70,-2.36,.13,-.00,.45,.33,.33,1.92,-.74,.09,-.65,-.11)*f0_1+
        mat4(.46,.32,.32,-1.91,-.25,-.29,.51,.31,.68,.20,-1.91,.07,.91,.19,-.16,.17)*f0_2+
        mat4(-1.12,.16,1.30,-.02,-.59,.43,1.29,.00,.07,-.20,-.06,.01,1.29,-.03,-.25,-.05)*f0_3+
        vec4(-.84,-.53,2.27,-1.30))/1.0+f0_1;
    vec4 f1_2=sin(mat4(.26,.07,-.40,.47,.04,.38,.43,.50,.05,.64,.33,.13,-.20,.26,-.10,.70)*f0_0+
        mat4(1.03,.15,.12,-.31,-.39,-.69,-1.47,-1.35,-.88,-.27,1.67,1.13,-.16,-.16,.49,-1.24)*f0_1+
        mat4(-.88,-.30,1.66,1.14,-.58,-.57,-.15,.38,-1.43,.23,-.05,-.47,-.54,.18,.16,.43)*f0_2+
        mat4(-.78,.92,.32,-.52,-.74,.53,.43,-.35,1.08,-.74,-.26,-1.09,.64,-.39,.15,.62)*f0_3+
        vec4(2.06,2.87,.46,-1.97))/1.0+f0_2;
    vec4 f1_3=sin(mat4(-.32,-1.03,.15,.20,-.19,-.88,.04,-.05,-.44,-.43,1.02,.10,-.02,.17,-.07,-.33)*f0_0+
        mat4(.06,2.45,-.25,-.22,-.01,-.53,-.12,-.22,.28,.87,-.06,.50,.60,-2.04,-.66,.09)*f0_1+
        mat4(.29,.85,-.06,.50,.07,-.59,-.61,-.33,-.84,-.81,-.56,.47,-.06,-.17,.42,-.32)*f0_2+
        mat4(-.77,1.29,.42,-.11,-.69,.91,-.05,.14,-.01,-.41,-1.55,.52,1.10,-.05,-.21,.27)*f0_3+
        vec4(1.25,2.26,3.59,1.23))/1.0+f0_3;
    vec4 f2_0=sin(mat4(-.37,1.93,1.64,-.27,-.75,-.24,-.37,-.18,1.51,-1.23,1.02,.27,-.83,.14,.57,.20)*f1_0+
        mat4(1.66,.53,.54,.55,.37,-3.52,1.62,1.72,-.07,-.29,.15,.23,-.21,1.43,-.13,.21)*f1_1+
        mat4(-.02,-.52,.14,.25,-.59,1.12,-.75,-.14,-.58,-.34,-.62,.31,-.58,1.11,.92,-.04)*f1_2+
        mat4(-.17,-1.10,.31,-.94,-.96,.35,-.06,-.12,.38,-1.48,1.04,.27,-.47,1.09,-1.76,1.23)*f1_3+
        vec4(.78,-1.51,-1.70,-.30))/1.4+f1_0;
    vec4 f2_1=sin(mat4(1.92,-1.36,.28,1.21,.56,.98,-.21,-.71,.89,-.41,.31,1.48,.47,.09,-.72,-.13)*f1_0+
        mat4(-.40,-.59,.50,1.09,-.88,.45,.23,-.72,-.09,-.26,-.04,.54,.47,-.20,.02,-.45)*f1_1+
        mat4(-.21,-.27,-.06,.52,2.09,1.19,.96,.36,-.26,.02,.38,-.69,.42,-.43,-.72,.01)*f1_2+
        mat4(2.63,.06,-.27,1.52,.53,.47,.07,.11,-.55,-.86,.10,.00,.07,1.05,.50,-.32)*f1_3+
        vec4(-2.37,5.12,-1.09,-2.25))/1.4+f1_1;
    vec4 f2_2=sin(mat4(.81,-.14,1.10,.17,.12,-.24,.31,-.08,.81,-.35,-.47,.16,.18,-.27,-.46,.32)*f1_0+
        mat4(.27,.19,-.66,.24,.74,-.93,-2.85,.28,.11,.15,.26,.86,.32,-.02,.07,.01)*f1_1+
        mat4(.08,.15,.21,.86,.69,.03,.11,.35,.01,-.31,-.80,-1.88,-.62,.30,.73,1.16)*f1_2+
        mat4(.76,-.16,1.54,1.22,.13,.27,1.36,.66,-.33,-.12,-.83,-.93,1.23,.06,.11,-1.64)*f1_3+
        vec4(-2.71,-1.53,.42,-.07))/1.4+f1_2;
    vec4 f2_3=sin(mat4(-.16,-1.51,-.23,-.90,-.11,-.62,-.74,.63,1.37,-.79,.58,-.96,-.41,-.16,.00,.56)*f1_0+
        mat4(-.18,.35,.01,-1.15,.07,1.33,1.03,1.26,.18,.63,.29,-.81,.61,.39,-.66,.70)*f1_1+
        mat4(.12,.60,.35,-.86,.21,-.86,.17,-.52,-.03,.47,-.53,.57,-1.34,.21,1.09,-.35)*f1_2+
        mat4(.56,-2.60,.27,-.68,.56,-1.01,-.05,.31,-.34,.71,-.07,-.36,-.32,1.49,-1.82,1.04)*f1_3+
        vec4(-.41,.70,-.56,-1.46))/1.4+f1_3;
    float d = dot(f2_0,vec4(.02,-.01,-.02,-.06))+
        dot(f2_1,vec4(-.02,-.04,-.07,-.03))+
        dot(f2_2,vec4(-.06,-.16,.03,.02))+
        dot(f2_3,vec4(.06,-.03,-.04,.03))+
        0.040;
   // limit to inside unit sphere as neural sdf is not really defined
   return max(d,length(p)-1.) - 0.015;
}


float G1V ( float dotNV, float k ) {
    return 1.0 / (dotNV*(1.0 - k) + k);
}

float GGX(vec3 N, vec3 V, vec3 L, float roughness, float F0) {
        float alpha = roughness*roughness;
    vec3 H = normalize (V + L);

    float dotNL = clamp (dot (N, L), 0.0, 1.0);
    float dotNV = clamp (dot (N, V), 0.0, 1.0);
    float dotNH = clamp (dot (N, H), 0.0, 1.0);
    float dotLH = clamp (dot (L, H), 0.0, 1.0);

    float D, vis;
    float F;

    float alphaSqr = alpha*alpha;
    float pi = 3.1415926535;
    float denom = dotNH * dotNH *(alphaSqr - 1.0) + 1.0;
    D = alphaSqr / (pi * denom * denom);

    float dotLH5 = pow (1.0 - dotLH, 5.0);
    F = F0 + (1.0 - F0)*(dotLH5);

    float k = alpha / 0.1;
    vis = G1V (dotNL, k) * G1V (dotNV, k);

    return D * F * vis;
}

float specular(vec3 p, vec3 rd, vec3 n, vec3 lp) {
    vec3 ld = normalize(lp - p);
    float roughness = 0.375;
    return GGX(n,-rd, ld,roughness, 0.2);
}

#define PI2      6.28318531
#define FLOAT_INF uintBitsToFloat(0x7f800000u)
const ivec3 iResolution3D = ivec3(64);


const uint PARTICLE_COUNT = uint(N_SPHERES);
const int slicesPerRow = 8;

vec4 worldToVoxel(vec4 raw) {
    return (raw + 3.0) * (1.0 / 6.0) * vec4(iResolution3D.x);
}

vec4 decodeEntity3D(sampler2D sampler, uint particleIndex)  {
    ivec2 texCoord = ivec2(particleIndex, 0);
    vec4 raw = texelFetch(sampler, texCoord, 0);

    return worldToVoxel(raw);
}

ivec3 to3D(uint flatId, ivec3 volumeSize) {
    int x = int(flatId % uint(volumeSize.x));
    int yz = int(flatId / uint(volumeSize.x));
    int y = yz % volumeSize.y;
    int z = yz / volumeSize.y;
    return ivec3(x, y, z);
}

uint to1D(ivec3 coord, ivec3 volumeSize) {
    return uint(coord.x) 
         + uint(coord.y) * uint(volumeSize.x)
         + uint(coord.z) * uint(volumeSize.x * volumeSize.y);
}


ivec2 to2D(uint flatId, ivec3 volumeSize) {
    ivec3 c3D = to3D(flatId, volumeSize);
    int sliceIndex = c3D.z;
    int row = sliceIndex / slicesPerRow;
    int col = sliceIndex % slicesPerRow;
    return ivec2(c3D.x + col * volumeSize.x, c3D.y + row * volumeSize.y);
}


ivec3 from2D(ivec2 texCoord, ivec3 volumeSize) {
    int col = texCoord.x / volumeSize.x;
    int x = texCoord.x % volumeSize.x;
    int y = texCoord.y % volumeSize.y;
    int z = col + (texCoord.y / volumeSize.y) * slicesPerRow;
    return ivec3(x, y, z);
}


uvec4 fetchClosest3D(vec3 position, sampler2D voroBuffer) {
    ivec3 ipos = ivec3(clamp(floor(position), vec3(0.0), vec3(iResolution3D) - 1.0));
    
    uint flatId = to1D(ipos, iResolution3D);
    ivec2 texCoord2D = to2D(flatId, iResolution3D);
    
    return floatBitsToUint(texelFetch(voroBuffer, texCoord2D, 0));
}

void sortClosest(
        inout vec4 distances,
        inout uvec4 indices, 
        uint index,
        vec3 center,
        sampler2D iChannel0
        ) {
    if (index == uint(-1) || any(equal(indices, uvec4(index)))) {
        return;
    } 

    vec4 e = decodeEntity3D(iChannel0, index);
    float dist = length(center - e.xyz) - e.w;
    
    if (dist < distances[0]) {
        distances = vec4(dist, distances.xyz);
        indices = uvec4(index, indices.xyz);
    } else if (dist < distances[1]) {
        distances = vec4(distances.x, dist, distances.yz); 
        indices = uvec4(indices.x, index, indices.yz);
    } else if (dist < distances[2]) {
        distances = vec4(distances.xy, dist, distances.z); 
        indices = uvec4(indices.xy, index, indices.z);
    } else if (dist < distances[3]) {
        distances = vec4(distances.xyz, dist);             
        indices = uvec4(indices.xyz, index);
    }
}


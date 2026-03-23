#define MIN_BLUR0 1.
#define MAX_BLUR0 32.
#define MIN_LOD1 0.
#define MAX_LOD1 8.
#define GAMMA 2.2


#define MAPMIN(a,b) (b.x < a.x) ? b : a

struct Material
{
    vec3 baseColor;
    float metallic;
    float roughness;
};
  
const vec3 DIELECTRIC_F0 = vec3(0.04);
const Material CHROME = Material(vec3(0.9,0.92,0.95), 1.0, 0.0);
const Material RED_PLASTIC = Material(vec3(0.95,0.3,0.2), 0.0, 0.3);
const Material BLUE_GRIME = Material(vec3(0.0,0.4,0.7), 0.0, 1.0);
const Material BLACK_PLASTIC = Material(vec3(0), 0.0, 0.0);
const Material GREEN_PLASTIC = Material(vec3(0.2,0.9,0.2), 0.0, 0.6);

Material matmix(Material a, Material b, float x)
{
    return Material(mix(a.baseColor, b.baseColor, x),
                    mix(a.metallic, b.metallic, x),
                    mix(a.roughness,  b.roughness, x));
}

// Image-based lighting trick by reinder:
// To approximate the integrated specular lobe in
// environment maps, we can use them with
// varying levels of detail.
// https://www.shadertoy.com/view/lscBW4
// https://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf

// Main problem : the mipmapping produces artifacts at object boundaries.
vec3 getSpecularLightColor( vec3 rd, float roughness )
{
    roughness = clamp(roughness, 0.0, 1.0);
    //float lod0 = mix(0.0, 8.0, roughness);
    float lod0 = log2(MIN_BLUR0 + (MAX_BLUR0-MIN_BLUR0) * roughness);
    float lod1 = mix(MIN_LOD1, MAX_LOD1, roughness);
    vec3 t0 = pow(textureLod(iChannel0, rd.xzy, lod0).rgb, vec3(GAMMA));
    vec3 t1 = pow(textureLod(iChannel1, rd.xzy, lod1).rgb, vec3(GAMMA));
    //return 0.5+0.5*rd.xzy;
    //return texture(iChannel0, rd.xzy, 0.).rgb;
    return 3.0*mix(t0, t1, smoothstep(0.25,0.8,roughness));
}

vec3 getDiffuseLightColor( vec3 rd )
{
    // So yeah, we don't really have a diffuse model
    return getSpecularLightColor(rd, 1.0);
}


vec4 map(vec3 p);
// Stolen from iq
// https://www.shadertoy.com/view/Xds3zN
float calcAO( in vec3 pos, in vec3 nor )
{
	float occ = 0.0;
    float sca = 1.0;
    for( int i=0; i<5; i++ )
    {
        float h = 0.01 + 0.12*float(i)/4.0;
        float d = map( pos + h*nor ).x;
        occ += (h-d)*sca;
        sca *= 0.95;
        if( occ>0.35 ) break;
    }
    return clamp( 1.0 - 3.0*occ, 0.0, 1.0 ) * (0.5+0.5*nor.z);
}


vec3 renderMaterial( vec3 p, vec3 rd, vec3 normal, Material mat )
{
    vec3 diffuseCol = getDiffuseLightColor(normal) * mat.baseColor * (1.0-mat.metallic);
    float ao = calcAO(p, normal);
    vec3 specularCol = getSpecularLightColor(reflect(rd, normal), mat.roughness);
    vec3 F0 = mix(DIELECTRIC_F0, mat.baseColor, mat.metallic);
    //vec3 F0 = DIELECTRIC_F0;
    vec3 fre = F0 + (1.0-F0)*pow(clamp(1.0-dot(-rd,normal),0.0,1.0), 5.0);
    //vec3 fre = F0;
    vec3 col = mix(diffuseCol, specularCol, fre)*ao;
    //col = specularCol;
    return col;
}


vec4 map( vec3 p )
{
    // map() -> vec4(d, normal)
    p.xy = mod(p.xy+0.5, 1.0)-0.5;
    vec4 d = vec4(length(p)-0.4, normalize(p));
    d = MAPMIN(d, vec4(p.z+0.41, vec3(0,0,1)));
	return d;
}

float bump( vec3 p )
{
    if(p.z > -0.4 && mod(p.x-0.5, 2.0) < 1.0)
        return 0.;
    p = vec3(p.x+p.y, p.x-p.y, sqrt(2.)*p.z);
    p = vec3(p.x+p.z, sqrt(2.)*p.y, p.x-p.z);
    p = fract(p*10.);
    float d = length(p - 0.5);
    return d*0.004;
}

float bumpMap( vec3 p )
{
    return map(p).x - bump(p);
}


vec3 calcNormal( vec3 p )
{
    float eps = 1e-3;
    vec2 e = eps*vec2(1,-1);
    return normalize(
          e.xxx*bumpMap(p+e.xxx)
        + e.xyy*bumpMap(p+e.xyy)
        + e.yxy*bumpMap(p+e.yxy)
        + e.yyx*bumpMap(p+e.yyx));
}


Material getMaterial( vec3 p )
{
    Material mat;
    if(p.z < -0.4)
        mat = GREEN_PLASTIC;
    else if (mod(p.x-0.5, 2.0) < 1.0)
        mat = RED_PLASTIC;
    else
        mat = CHROME;
        
    float grime = smoothstep(0.1,0.6,texture(iChannel2,p.xy*0.1).r);
    mat = matmix(mat, BLUE_GRIME, grime);
    return mat;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = (2.0*fragCoord.xy - iResolution.xy)/iResolution.x;
    
    float th = iTime * 0.1;
    vec3 ro = vec3(3.0*cos(th), 3.0*sin(th), 3.0);
    vec3 target = vec3(0);
    vec3 camFwd = normalize(target-ro);
    vec3 camRight = normalize(cross(camFwd, vec3(0,0,1)));
    vec3 camUp = cross(camRight, camFwd);
    float fov = 0.5;
    vec3 rd = normalize(camFwd + fov*(uv.x*camRight + uv.y * camUp));
    
    vec3 col;
    
    #if 0
    {
    vec3 rdScreen = normalize(vec3(uv.x, uv.y, 2));
    vec3 rd = rdScreen;
    float th = 0.2*iTime;
    float th2 = -sin(0.2*iTime);
    rd.yz *= mat2(cos(th2),sin(th2),-sin(th2),cos(th2));
    rd.xz *= mat2(cos(th),sin(th),-sin(th),cos(th));
    
    float nSpheres = 7.0;
    vec2 c = 2./nSpheres * round(uv*nSpheres/2.);
    c.x = clamp(c.x,-1.0,1.0);
    c.y = clamp(c.y, -2.0/nSpheres, 0.0);
    vec3 normal;
    float d = length(uv - c) * nSpheres;
    
    col = getSpecularLightColor(rd, 0.0);
   	if(d < 0.98)
    {
        normal = normalize(vec3(uv-c, -sqrt(1.0-d*d)));
        vec3 rr = reflect(normalize(vec3(uv-c, 2)), normal);
        rr.yz *= mat2(cos(th2),sin(th2),-sin(th2),cos(th2));
        rr.xz *= mat2(cos(th),sin(th),-sin(th),cos(th));
        float roughness = smoothstep(-1.0, 1.0, c.x);
        if(c.y < 0.0)
        	roughness = mix(roughness, 1.0, texture(iChannel2, nSpheres*uv).r);
        col = getSpecularLightColor(rr, roughness);
    }
    }
    #endif
    
    vec4 d;
    float t=0.0;
    for(int i=0;i<256;i++)
    {
        d = map(ro+t*rd);
        if(d.x < 0.001 || t > 100.) break;
        t += d.x;
    }
    
    if(d.x < 0.001)
    {
        vec3 p = ro+t*rd;
        col = 0.1*vec3(t);
        vec3 normal = calcNormal(p);
        //vec3 normal = d.yzw;
        Material mat = getMaterial(p);
        col = renderMaterial(p, rd, normal, mat);
        //col = mat.baseColor;
        //col = 0.5+0.5*vec3(normal.x, p.z-0.4, normal.y);
        //col = 0.5+0.5*normal;
        //col = vec3(calcAO(p, normal));
        //col = 0.5+0.5*vec3(reflect(rd, normal));
    }
    else
    {
        col = getSpecularLightColor(rd, 0.0);
    }
    
    col = pow(col, vec3(1.0/GAMMA));
    
    // Output to screen
    fragColor = vec4(col,1.0);
}

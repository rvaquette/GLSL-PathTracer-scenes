// IMAGE-BASED LIGHTING OF CUSTOM MATERIALS
// Alexis THIBAULT - 09/2020


#define MIN_BLUR 1.
#define MAX_BLUR 64.
#define GAMMA 2.2




// The material model is inspired from
// https://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf
// "Metallic" and "roughness" range from 0 to 1 and are
// approximately perceptually linear.
struct Material
{
    vec3 baseColor;
    float metallic;
    float roughness;
};
  
const vec3 DIELECTRIC_F0 = vec3(0.04);

// Some examples of materials
const Material CHROME = Material(vec3(0.9,0.92,0.95), 1.0, 0.0);
const Material RED_PLASTIC = Material(vec3(0.95,0.3,0.2), 0.0, 0.1);
const Material RED_METAL = Material(vec3(0.95,0.3,0.2), 1.0, 0.2);
const Material BLUE_GRIME = Material(vec3(0.0,0.4,0.7), 0.0, 1.0);
const Material BLACK_PLASTIC = Material(vec3(0), 0.0, 0.0);
const Material GREEN_PLASTIC = Material(vec3(0.2,0.9,0.2), 0.0, 0.6);

// Materials can be blended together, e.g. for layering.
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
vec3 getSpecularLightColor( vec3 rd, float roughness )
{
    roughness = clamp(roughness, 0.0, 1.0);
    float lod = log2(mix(MIN_BLUR, MAX_BLUR, roughness));
    // The large cubemap does not capture well high-intensity lights,
    // so mix it with the small version.
    vec3 t0 = pow(textureLod(iChannel0, rd.xzy, lod).rgb, vec3(GAMMA));
    vec3 t1 = pow(textureLod(iChannel1, rd.xzy, lod).rgb, vec3(GAMMA));
    vec3 col = mix(t0, t1, roughness);
    // White balance
    vec3 wb = pow(vec3(205.,159.,147.)/255.,vec3(-GAMMA));
    return 3.0*wb*col;
}

vec3 getDiffuseLightColor( vec3 rd )
{
    // So yeah, we don't really have a diffuse model
    return getSpecularLightColor(rd, 1.0);
}


float map(vec3 p);

// Ambient Occlusion computation stolen from iq
// https://www.shadertoy.com/view/Xds3zN
float calcAO( in vec3 pos, in vec3 nor )
{
	float occ = 0.0;
    float sca = 1.0;
    for( int i=0; i<5; i++ )
    {
        float h = 0.01 + 0.12*float(i)/4.0;
        float d = map( pos + h*nor );
        occ += (h-d)*sca;
        sca *= 0.95;
        if( occ>0.5 ) break;
    }
    return clamp( 1.0 - 2.0*occ, 0.0, 1.0 ) * (0.5+0.5*nor.z);
}


vec3 renderMaterial( vec3 p, vec3 rd, vec3 normal, Material mat )
{
    vec3 diffuseBaseColor = mix(mat.baseColor, vec3(0), mat.metallic);
    vec3 diffuseCol = getDiffuseLightColor(normal) * diffuseBaseColor;
    vec3 specularCol = getSpecularLightColor(reflect(rd, normal), mat.roughness);
    vec3 F0 = mix(DIELECTRIC_F0, mat.baseColor, mat.metallic);
    vec3 fre = F0 + (1.0-F0)*pow(clamp(1.0-dot(-rd,normal),0.0,1.0), 5.0);
    vec3 col = mix(diffuseCol, specularCol, fre);
    
    // Add ambient occlusion for more convincing lighting
    // (bouncing rays would be better)
    float ao = calcAO(p, normal);
    return col*ao;
}


float map( vec3 p )
{
    p.xy = mod(p.xy+0.5, 1.0)-0.5;
    float d = length(p)-0.4;
    d = min(d, p.z+0.41);
	return d;
}

float bump( vec3 p )
{
    if(p.z > -0.4)// && mod(p.x-0.5, 2.0) < 1.0)
        return 0.;
    p = vec3(p.x+p.z, sqrt(2.)*p.y, p.x-p.z);
    p = vec3(p.x+p.y, p.x-p.y, sqrt(2.)*p.z);
    p = fract(p*4.);
    float d = length(p - 0.5);
    d = d*d;
    return -d*0.002;
}

float bumpMap( vec3 p )
{
    return map(p) - bump(p);
}


vec3 calcNormal( vec3 p, float eps )
{
    //float eps = 1e-3;
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

    mat = Material(vec3(0.5),0.,0.);
    mat.metallic = 1.0-step(0.0,p.y);
    mat.roughness = smoothstep(-3.0,3.0,p.x);
    return mat;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (2.0*fragCoord.xy - iResolution.xy)/iResolution.x;
    
    float th = iTime * 0.2;
    vec3 ro = vec3(4.0*sin(th), -4.0*cos(th), 3.0+2.0*sin(th*1.618));
    //vec3 ro = vec3(0.0,-3.0+2.0*sin(th),6.0 + 2.0*cos(th));
    vec3 target = vec3(0);
    vec3 camFwd = normalize(target-ro);
    vec3 camRight = normalize(cross(camFwd, vec3(0,0,1)));
    vec3 camUp = cross(camRight, camFwd);
    float fov = 0.5;
    vec3 rd = normalize(camFwd + fov*(uv.x*camRight + uv.y * camUp));
    
    vec3 col;
    
    float d;
    float t=0.0;
    for(int i=0;i<256;i++)
    {
        d = map(ro+t*rd);
        if(d < 0.001 || t > 100.) break;
        t += d;
    }
    
    if(t < 100.)
    {
        vec3 p = ro+t*rd;
        vec3 normal = calcNormal(p, 0.001);
        Material mat = getMaterial(p);
        col = renderMaterial(p, rd, normal, mat);
    }
    else
    {
        // We didn't hit anything, return world color
        col = getSpecularLightColor(rd, 0.0);
    }
    
    col = pow(col, vec3(1.0/GAMMA));
    
    // Output to screen
    fragColor = vec4(col,1.0);
}

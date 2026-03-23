const vec3 ambientLight = vec3(0.1);
const vec3 specColor = vec3(0.04);

const float EPSILON = 0.00001;

const float UNITY_INV_PI = 0.31830988618f;
const float UNITY_PI = 3.14159265359f;

const int maxSteps = 256;

#define SHOW_NORMAL 0
#define SHOW_DEPTH 0
#define SHOW_MATERIAL_BASECOLOR 0
#define SHOW_MATERIAL_SMOTHNESS 0

#define SHOW_FOG 0
#define CAMERA_ROTATE 1
#define LIGHT_ROTATE 0
#define LIGHT_ADD 0

#define SMOTHNESS_TEST 1

float showNormal;
float showDepth;
float showReflection;

struct LightData
{
    vec3 pos;
    float intensity;
    vec3 color;
};
    
LightData mainLight() {
    LightData l;

    l.intensity = 1.0;
	l.pos = vec3(30.32, 20.77, 0.56);
    #if LIGHT_ROTATE
    	l.pos = vec3(30.32*sin(iTime), 20.77, 0.56*cos(iTime));
    #endif
    l.color = vec3(1.0, 1.0, 1.0) * l.intensity;
    return l;
}

LightData addLight() {
    LightData l;

    l.intensity = 1.0;
	l.pos = vec3(-30.32, 20.77, 0.56);
    l.color = vec3(0.2, 0.9, 0.67) * l.intensity;
    return l;
}

struct MaterialData
{
    vec3 diffColor;
    float smoothness; 
};

float sdPlane( vec3 p, vec3 o)
{
  return p.y;
}

float udBox( vec3 p, vec3 o, vec3 b )
{
  return length(max(abs(p - o)-b,0.0));
}

float sdSphere( vec3 p, vec3 o, float s )
{
  return length(p - o)-s;
}

vec2 opU( vec2 d1, vec2 d2 )
{
	return (d1.x<d2.x) ? d1 : d2;
}

vec2 sceneSDF(vec3 samplePoint) {
    
    vec2 res = vec2(1e10, 0.0);
    
    vec2 cube = vec2(udBox(samplePoint,vec3(-1.0, 0.8, 0.0), vec3(0.8)), 4.0);
    vec2 sphere = vec2(sdSphere(samplePoint, vec3(2.0, 1.0, 2.0), 1.0), 2.0);
    vec2 plane = vec2(sdPlane(samplePoint, vec3(0.0, 0.0, 0.0)), 0.0);
    vec2 sphere2 = vec2(sdSphere(samplePoint, vec3(2.0, 1.0, -2.0), 1.0), 8.0);
    
	res = opU(res, cube);
    res = opU(res, sphere);
    res = opU(res, sphere2);
    res = opU(res, plane);
    
    return res;
}

vec3 estimateNormal(vec3 p) {
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)).x - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)).x,
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)).x - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)).x,
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)).x - sceneSDF(vec3(p.x, p.y, p.z - EPSILON)).x
    ));
}

float DisneyDiffuse(float NdotV, float NdotL, float LdotH, float perceptualRoughness)
{
    float fd90 = 0.5 + 2.0 * LdotH * LdotH * perceptualRoughness;
    // Two schlick fresnel term
    float lightScatter   = (1.0 + (fd90 - 1.0) * pow(1.0 - NdotL, 5.0));
    float viewScatter    = (1.0 + (fd90 - 1.0) * pow(1.0 - NdotV, 5.0));

    return lightScatter * viewScatter;
}

float GGXTerm (float NdotH, float roughness)
{
    float a2 = roughness * roughness;
    float d = (NdotH * a2 - NdotH) * NdotH + 1.0f; // 2 mad
    return UNITY_INV_PI * a2 / (d * d + 1e-7f); // This function is not intended to be running on Mobile,
                                            // therefore epsilon is smaller than what can be represented by half
}

float SmithJointGGXVisibilityTerm (float NdotL, float NdotV, float roughness)
{
    float a = roughness;
    float lambdaV = NdotL * (NdotV * (1.0 - a) + a);
    float lambdaL = NdotV * (NdotL * (1.0 - a) + a);
    return 0.5f / (lambdaV + lambdaL + 1e-5f);
}

vec3 FresnelTerm (vec3 F0, float cosA)
{
    float t = pow(1.0 - cosA, 5.0);   // ala Schlick interpoliation
    return F0 + (1.0-F0) * t;
}
vec3 FresnelLerp (vec3 F0, vec3 F90, float cosA)
{
    float t = pow(1.0 - cosA, 5.0);   // ala Schlick interpoliation
    return mix (F0, F90, t);
}

float calcSoftshadow( in vec3 ro, in vec3 rd, in float mint, in float tmax )
{
    // bounding volume
    float tp = (2.5-ro.y)/rd.y; if( tp>0.0 ) tmax = min( tmax, tp );

    float res = 1.0;
    float t = mint;
    for( int i=0; i<32; i++ )
    {
		float h =sceneSDF( ro + rd*t ).x;
        float s = clamp(8.0*h/t,0.0,1.0);
        res = min( res, s*s*(3.0-2.0*s) );
        t += clamp( h, 0.02, 0.10 );
        if( res<0.005 || t>tmax ) break;
    }
    return clamp( res, 0.0, 1.0 );
}

vec3 BRDF(LightData light, vec3 p, vec3 eye, vec3 rd, MaterialData mat)
{
    float smoothness = mat.smoothness;
    vec3 diffColor = mat.diffColor * 0.96;
    float perceptualRoughness = 1.0 - smoothness;
    float roughness = perceptualRoughness * perceptualRoughness;
    roughness = max(roughness, 0.002);
    
    float sd = calcSoftshadow(p, light.pos, 0.03, 2.5);
    
    vec3 N = estimateNormal(p);
    vec3 L = normalize(light.pos - p);
    vec3 viewDir = normalize(eye - p);
    vec3 H = normalize(L+viewDir);
    vec3 R = normalize(reflect(-L, N));
    
    // 计算反射
    vec3 ref = reflect(rd, N );
    float dom = smoothstep( -0.2, 0.2, ref.y);
    dom *= calcSoftshadow(p, ref, 0.2, 2.5);
    
  
    //return vec3(dom);
    vec3 reflectColor = smoothness*dom*vec3(0.40,0.60,1.30);
    
    if (showReflection > EPSILON) {
		return reflectColor;
    }
    float NdotL = clamp(dot(N, L), 0.0, 1.0) * sd;
    float NdotV = clamp(dot(N, viewDir), 0.0, 1.0);
    float LdotH = clamp(dot(L, H), 0.0, 1.0);
    float NdotH = clamp(dot(N, H), 0.0, 1.0);
    
    float diffuseTerm = DisneyDiffuse(NdotV, NdotL, LdotH, perceptualRoughness) * NdotL;
    float D = GGXTerm (NdotH, roughness);
    float V = SmithJointGGXVisibilityTerm (NdotL, NdotV, roughness);
    float specularTerm = V*D * UNITY_PI;
    specularTerm = max(0.0, specularTerm * NdotL);
    
    float surfaceReduction = 1.0 / (roughness*roughness + 1.0);
    vec3 grazingTerm = vec3(clamp(smoothness + 0.04, 0.0, 1.0));
    
    vec3 color = diffColor *(ambientLight + light.color * diffuseTerm)
        		+ specularTerm * light.color * FresnelTerm (specColor, LdotH) 
        		+ surfaceReduction * reflectColor * FresnelLerp (specColor, grazingTerm, NdotV);
    
    return color;
}

vec3 illumination (vec3 p, vec3 eye, vec3 rd, MaterialData mat)
{
	LightData light1 = mainLight();
    
    vec3 color = BRDF(light1, p, eye, rd, mat);
    
    #if LIGHT_ADD
    	LightData light2 = addLight();
        vec3 addColor = BRDF(light2, p, eye, rd, mat);
        color += addColor;
    #endif
    
    return color;
}

vec3 ACESToneMapping(vec3 color, float adapted_lum)
{
	const float A = 2.51f;
	const float B = 0.03f;
	const float C = 2.43f;
	const float D = 0.59f;
	const float E = 0.14f;
 
	color *= adapted_lum;
	return (color * (A * color + B)) / (color * (C * color + D) + E);
}


float checkers( in vec2 p )
{
    vec2 q = floor(p);
    return mod(q.x+q.y,2.);
}

MaterialData GetDiffColor(vec3 p, float m) 
{
    MaterialData material;
    if (m < EPSILON) {	
        material.diffColor = checkers(p.xz) * vec3(0.5, 0.0, 0.0);
        material.smoothness = 1.0;
    } else if (m - 2.0 < EPSILON) {
        material.diffColor = vec3(0.0, 0.5, 0.0) ;
        material.smoothness = 0.9;
        #if SMOTHNESS_TEST
        	material.smoothness = abs(sin(iTime));
        #endif
        
    } else if (m - 4.0 < EPSILON) {
        material.diffColor = vec3(0.0, 0.0, 0.5) ;
        material.smoothness = 0.2;
    } else if (m - 8.0 < EPSILON) {
        material.diffColor = vec3(0.98, 0.51, 0.91) ;
        material.smoothness = 0.2;
    } else {
        material.diffColor = vec3(0.5);
    	material.smoothness = 0.5;
    }
    
    return material;
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv1 = fragCoord/iResolution.xy;
	vec2 uv = 2.0 * uv1;
    //vec2 uv = uv1;
    uv = fract(uv);
	uv -= .5;
    uv.x *= iResolution.x / iResolution.y;
    
    uv1 -= .5;
    uv1.x *= iResolution.x / iResolution.y;

    showNormal = step(uv1.x, 0.0) * step(uv1.y, 0.0);
    showDepth = step(-uv1.x, 0.0) * step(uv1.y, 0.0);
    showReflection = step(-uv1.x, 0.0) * step(-uv1.y, 0.0);
   
    // 设置相机位置
    vec3 ro = vec3(6.0,6.0, -6.0);
    //ro += vec3( 4.5*cos(0.1*iTime + 16.0), 1.0 + 2.0, 4.5*sin(iTime + 16.0) );
    #if CAMERA_ROTATE
        ro = vec3(10.5*cos(iTime * 0.2), 5.0, -10.5*sin(iTime * 0.2));
    #endif
    	

    float zoom = 1.0;
   	// 设置看向的点
    vec3 lookAt = vec3(0.5, 0.5, 0.5);
    
    // 格拉姆—施密特正交化
    vec3 f = normalize(lookAt - ro);
    vec3 r = cross(vec3(0.0, 1.0, 0.0), f);
    vec3 u = cross(f, r);
    
    vec3 c = ro + f*zoom;
    // 将2纬UV 升到 3纬坐标
    vec3 i = c + uv.x*r + uv.y*u;
    // 得到相机指向UV点的向量
	vec3 rd = i - ro;
    
    vec4 color = vec4(0.0);
    
    // Ray Marching
    float t = 0.0;
    
    for(int i = 0; i < maxSteps; ++i)
    {
        vec3 p = ro + rd * t;
       	
        vec2 res = sceneSDF(p);
        float d = res.x;
        float m = res.y;
        
        if(d < EPSILON)
        {
            if (showNormal > EPSILON) {
                color.rgb = (estimateNormal(p) + 1.0) * 0.5;
            } else if (showDepth > EPSILON) {
                color.rgb = vec3(t/20.0);
            } else {
                
                // 获取命中物体的材质属性
                MaterialData mat = GetDiffColor(p, m);

                #if SHOW_MATERIAL_BASECOLOR
                color.rgb = pow(mat.diffColor, vec3(0.4545));
                #elif SHOW_MATERIAL_SMOTHNESS
                color.rgb = vec3(mat.smoothness);
                #else
                // 渲染
                color.rgb += illumination(p, ro, rd, mat);
                #endif
            }
            	

            

            
            break;
        }

        float add = d;
        
        t += add;
        
        #if SHOW_FOG
        	color.rgb = mix( color.rgb, vec3(0.9), 1.0-exp( -0.00001*t*t ) );
        #endif
        
    }
    
    // Tonemapping
    color.rgb = ACESToneMapping(color.rgb, 1.0);
    // 抵消屏幕Gamma矫正
    color.rgb = pow( color.rgb, vec3(0.4545) );
    
    fragColor = color;
}

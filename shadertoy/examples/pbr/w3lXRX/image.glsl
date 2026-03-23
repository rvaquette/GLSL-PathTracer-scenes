///////////////////////////////////////////////////////////////////////////////////

// comment me out if you need some more FPS!
#define HIGHER_QUALITY

///////////////////////////////////////////////////////////////////////////////////

#define MARCH_ITERATIONS 	250
#define MARCH_DELTA			0.005
#define MARCH_DELTA2		1.01
#define START_DIST 			3.5
    
///////////////////////////////////////////////////////////////////////////////////

Material g_NoMaterial = Material(vec3(1.0, 0.0, 1.0), 0.0, 1.0);
Result g_result;
    
///////////////////////////////////////////////////////////////////////////////////

const int lightarraysize = 2;
const int numlights = 1;
Light g_lights[lightarraysize];

///////////////////////////////////////////////////////////////////////////////////
// IQ's noise functions

float noise2( in vec3 x )
{
    vec3 p = floor(x);
    vec3 f = fract(x);
	f = f*f*(3.0-2.0*f);
    //f = (f*f*(3.0-2.0*f)+f)*0.5;
	vec2 uv = (p.xy+vec2(37.0,17.0)*p.z) + f.xy;
	vec2 rg = textureLod( iChannel0, (uv+ 0.5)/256.0, 0. ).yx;
	return mix( rg.x, rg.y, f.z );
}

float mist(vec3 p, int LOD)
{   
    vec3 p2 = p;
    p *= 2.25;
    float weight = 0.25;
    float totalweight = 0.0;
    float value = 0.0;
    for (int i=0; i<LOD; i++)
    {
        totalweight += weight;
        value += noise2(p)*weight;    
        p *= 2.03;
        weight *= 0.7;
    }
    
    if (length(p2-vec3(0.0, 0.0, 0.0)) > 2.5)
        return 0.0;
        
    return 0.01 + value/totalweight;
}

Result raymarch_query(inout Ray ray, int iterations, float delta)
{
    Result result = Result(ray.pos+ray.dir*10000.0, vec3(0.0, 0.0, 0.0), g_NoMaterial, vec4(0.0, 0.5, 0.0, 0.0));    
    float dist = 0.0;
    float fog=0.0;
    float dstalpha = 0.0;
    float srcalpha = 0.0;
    const float densitythreshold = 0.70;
    const float densityscale = 100.0/(1.0-densitythreshold);
    const float lightstep = 0.6;
    const float lightatten = 1.0 / (sqrt(lightstep)*1.8);
    
    vec3 lighting = vec3(-1.0, -1.0, 1.0);
    lighting = normalize(lighting);
    
    float time = iTime + 1.5;
    float material = sin(time*0.5);
    float transtint = 1.0;
    float opaquetint = 0.0;
    
	for (int i=0; i<iterations; i++)
    {        
		float v = mist(ray.pos, 3);
        vec3 colour = vec3(0.0);
        float density = 0.0;
        if (v>0.2)
        {
			colour = mix(vec3(0.2, 1.0, 0.7)*sqrt(transtint), vec3(1.0, 1.0, 1.0)*sqrt(opaquetint), v);
			//colour = mix(vec3(0.0), vec3(1.0), v);
            
            vec3 norm=vec3(mist(ray.pos+vec3(0.2, 0.0, 0.0), 3), 
                           mist(ray.pos+vec3(0.0, 0.2, 0.0), 3), 
                           mist(ray.pos+vec3(0.0, 0.0, 0.2), 3));
            norm=normalize(norm);
            
            density = (v-0.6)*2.0;            
            
            vec3 reflected = reflect(ray.dir, norm);
            colour += texture(iChannel1, reflected).xyz*1.7*(1.0-dstalpha);
            
            vec3 refracted = refract(ray.dir, norm, 1.0);
            ray.dir = mix(ray.dir, refracted, 0.01);
            ray.dir=normalize(ray.dir);
            
            // density is the value times the step       
            density*=clamp(delta*10.0, 0.0, 1.0);
            // update the alpha
            srcalpha = density;

            if (srcalpha>0.01)
            {                
                // modify the destingation alpha, based on the current srcalpha
                float prevdstalpha = dstalpha;
                dstalpha = dstalpha + srcalpha*(1.0 - dstalpha);
                result.fog.xyz = mix(colour, result.fog.xyz, prevdstalpha/dstalpha);
            }
            if (dstalpha>0.95)
            {
                result.fog.w = dstalpha;
                return result;            
            }            
        }
             
        ray.pos += ray.dir*delta;
        delta*=MARCH_DELTA2;
    }
            
   	result.fog.w = dstalpha;
    return result;
}

///////////////////////////////////////////////////////////////////////////////////

vec3 raymarch(Ray inputray, in vec2 fragCoord)
{
    vec2 uv = fragCoord.xy / iResolution.xy * 2.0 - 1.0;
    uv.y *= iResolution.y / iResolution.x;    
    
    vec3 colour = vec3(0.0, 0.0, 0.0);
    Ray ray=inputray;        
    g_result = raymarch_query(ray, MARCH_ITERATIONS, MARCH_DELTA);
    colour = mix(texture(iChannel1, ray.dir).xyz, g_result.fog.xyz, g_result.fog.w);       
        
    return colour;    
}

///////////////////////////////////////////////////////////////////////////////////
// main loop

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{           
    fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    
    Ray ray;
    vec2 uv = fragCoord.xy / iResolution.xy * 2.0 - 1.0;
    uv.y *= iResolution.y / iResolution.x;
    
    float time = iTime;    
    vec3 p0, p1;
    
    vec3 stick;
    vec2 sunVec;
    if (iMouse.x<20.0)
    {
        stick = vec3(0.5 + sin(time*0.5)*0.5, -0.25 + cos(time*0.35)*0.5, -1.0);        
    }    
    else
    {
		stick = vec3(iMouse.x/iResolution.x, iMouse.y/iResolution.y - 0.5, -1.0);        
    }
    
    stick = normalize(stick);
    p0=stick*6.0;
    p1=vec3(0.0, 0.0, 0.0);
    //ViewVector(time, p0, p1); 
        
    vec3 dir = (p1-p0);
    dir = normalize(dir);
    vec3 up = vec3(0.0, 1.0, 0.0);
    up = normalize(up);
    vec3 right = cross(dir, up);
    right = normalize(right);
    up = cross(right, dir);
    up = normalize(up);
    
    ray.pos = p0;
    ray.dir = dir*1.0 + up*uv.y + right*uv.x;
    ray.dir = normalize(ray.dir);
        
    ray.pos += ray.dir*START_DIST;
            
    fragColor.xyz = vec3(0.0);        
    fragColor.xyz += raymarch(ray, fragCoord); 
}

///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////


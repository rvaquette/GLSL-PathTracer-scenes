/*
"Cloth Texture Simulation" by Emmanuel Keller aka Tambako - February 2016
License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
Contact: tamby@tambako.ch
*/

#define pi 3.141593

const float tbrl = 3.;
const float difi = 0.73;
const float specint = 0.002;
const float specshin = 0.8;
const float aoint = 0.42;
const float ssstrmr = 0.18;
const float sssInt = 0.35;

const float txti0 = 0.4;
const float txtf = 30.;

float normdelta = 0.00002;

const float fr0 = 0.022;
float fr;
const float fe = 0.057;
const float fd = 0.395;
const float fds = 0.176;
const float twf = 65.;
const float twfs = -110.;
const float clsize = 60.;
const float tdv = 0.22;
const float tdd = 0.15;
const float ttwd = 0.002;
const float crv = 0.2;
const vec2 ffa = vec2(0.14, 0.37);
const float fft = 0.68;

const float maxdist = 1500.;


#define SPECULAR
#define SH_OA
#define SS_SCATERING
#define COL_TEXTURE
#define POSSIZE_VAR

float gtf;
float gtf2;

vec2 rotateVec(vec2 vect, float angle)
{
    vec2 rv;
    rv.x = vect.x*cos(angle) + vect.y*sin(angle);
    rv.y = vect.x*sin(angle) - vect.y*cos(angle);
    return rv;
}

// Simple "random" function
float random(float co)
{
    return fract(sin(co*752.19) * 238.5);
}

float map_f_hor(vec3 pos, vec2 delta, float n)
{
    return length(vec2(mod(pos.y + delta.x, fe) - fe*0.6, pos.z + delta.y + fr*sin((pos.x + fe*2. + fe*floor(pos.y/fe))/fe*pi))) - fr*fds*0.86;
}

float hsf;
float map_hor_small(vec3 pos, vec2 delta, float n)
{
    float fy = 132.*random(12.54*floor(pos.y/fe));
    float ad = 1. + ttwd*hsf;
                          
    float angle = ad*twf*pos.x;
    vec2 d1 = rotateVec(vec2(fr*fd, fr*fd), angle);
    vec2 d2 = d1.yx*vec2(1., -1);
    return min(min(min(map_f_hor(pos, d1 + delta, n + 1.), map_f_hor(pos, d2 + delta, n + 2.)), map_f_hor(pos, -d2 + delta, n + 3.)), map_f_hor(pos, -d1 + delta, n + 4.)); 
}

float pyd;
float map_hor(vec3 pos)
{  
    float fy = 132.*random(1.254*floor(pos.y/fe));

    fy = 17.5*random(2.452*floor(pos.y/fe));
    pyd = fe*tdd*(1. - 0.45*0.5*sin(pos.x*2.15 + 13.*fy) - 0.3*0.5*sin(pos.x*4.12 + 42.*fy) - 0.25*0.5*sin(pos.y*8.72 + 70.*fy));
    pos.y+= pyd;

    hsf = 0.35*sin(pos.x*4.3 + 20.*fy) + 0.4*sin(pos.x*5.7 + 45.*fy) + 0.25*sin(pos.x*8.48 + 55.*fy);
    fr = fr0*(-tdv*0.5 + 1. - 0.5*tdv*hsf);
    
    float angle = twfs*pos.x;
    vec2 d1 = rotateVec(vec2(fr*fds, fr*fds), angle);
    vec2 d2 = d1.yx*vec2(1., -1);
    return min(min(min(map_hor_small(pos, d1, 1.), map_hor_small(pos, d2, 5.)), map_hor_small(pos, -d2, 9.)), map_hor_small(pos, -d1, 13.)); 
}

float map_f_ver(vec3 pos, vec2 delta, float n)
{
    return length(vec2(mod(pos.x + delta.x, fe) - fe*0.6, pos.z + delta.y - fr*sin((pos.y + fe*2. + fe*floor(pos.x/fe))/fe*pi))) - fr*fds*0.86;
}

float vsf;
float map_ver_small(vec3 pos, vec2 delta, float n)
{    
    float fx = 145.*random(19.36*floor(pos.x/fe));
    float ad = 1. + ttwd*vsf;            
    
    float angle = ad*twf*pos.y;
    vec2 d1 = rotateVec(vec2(fr*fd, fr*fd), angle);
    vec2 d2 = d1.yx*vec2(1., -1);
    return min(min(min(map_f_ver(pos, d1 + delta, n + 1.), map_f_ver(pos, d2 + delta, n + 2.)), map_f_ver(pos, -d2 + delta, n + 3.)), map_f_ver(pos, -d1 + delta, n + 4.)); 
}

float pxd;
float map_ver(vec3 pos)
{   
    float fx = 145.*random(1.936*floor(pos.x/fe));
    
    fx = 45.8*random(1.885*floor(pos.x/fe)); 
    pxd = fe*tdd*(1. + 0.45*0.5*sin(pos.y*1.3 + 27.*fx) + 0.3*0.5*sin(pos.y*3.7 + 74.*fx) - 0.25*0.5*sin(pos.y*9.48 + 112.*fx));
    pos.x+= pxd;
    
    vsf = 0.35*tdv*sin(pos.y*4.3 + 31.*fx) - 0.4*tdv*sin(pos.y*5.7 + 58.*fx) - 0.25*tdv*sin(pos.y*8.48 + 38.*fx);
    fr = fr0*(-tdv*0.5 + 1. - 0.5*tdv*vsf);
    
    float angle = twfs*pos.y;
    vec2 d1 = rotateVec(vec2(fr*fds, fr*fds), angle);
    vec2 d2 = d1.yx*vec2(1., -1);
    return min(min(min(map_ver_small(pos, d1, 1.), map_ver_small(pos, d2, 5.)), map_ver_small(pos, -d2, 9.)), map_ver_small(pos, -d1, 13.)); 
}

float map_s(vec3 pos)
{  
    vec3 pos0 = pos;
    float fy = 132.*random(1.254*floor(pos.y/fe));
    fr = fr0*(-tdv*0.5 + 1. - 0.5*hsf);

    pos.y+= pyd;
    float fh = length(vec2(mod(pos.y, fe) - fe*0.6, pos.z + fr*sin((pos.x + fe*2. + fe*floor(pos.y/fe))/fe*pi))) - fr*1.1;
 
    pos = pos0;
    
    float fx = 145.*random(1.936*floor(pos.x/fe));
    fr = fr0*(-tdv*0.5 + 1. - 0.5*vsf);
    
    pos.x+= pxd;
    
    float fv = length(vec2(mod(pos.x, fe) - fe*0.6, pos.z - fr*sin((pos.y + fe*2. + fe*floor(pos.x/fe))/fe*pi))) - fr*1.1;
    return min(fh, fv);
}

float map_s2(vec3 pos)
{
    return mix(map_s(pos), abs(pos.z) - fr*1.1, smoothstep(14., 23., iTime));
}

float map(vec3 pos)
{
    float disth = map_hor(pos);
    float distv = map_ver(pos);
    return mix(min(disth, distv), map_s2(pos), gtf);
}

vec2 trace(vec3 cam, vec3 ray, float maxdist) 
{
    float o;
    float t = -cam.z/ray.z -0.05;
    
  	for (int i = 0; i < 64; ++i)
    {
    	vec3 pos = ray*t + cam;
    	float dist = map(pos);
        if (dist<0.0006 || dist>maxdist)
        {
            o = (abs(dist-map_ver(pos))<abs(dist-map_hor(pos))?1.:0.);
            break;
        }
        t+= dist*(0.85 + float(i)*0.02);
  	}
  	return vec2(t, o);
}

// From https://www.shadertoy.com/view/MstGDM
vec3 getNormal(vec3 pos, float e, float o)
{
    vec2 q = vec2(0., e); //vec2(0.,distance(campos, pos)*0.0005);
    return normalize(vec3(map(pos + q.yxx) - map(pos - q.yxx),
                          map(pos + q.xyx) - map(pos - q.xyx),
                          map(pos + q.xxy) - map(pos - q.xxy)));
}

vec4 char(vec2 pos, float c) {
    pos = clamp(pos,0.,1.);  // would be more efficient to exit if out.

    vec4 tx= texture( iChannel3, pos/16. + fract( floor(vec2(c, 15.999-c/16.)) / 16. ) )*2. ;
    vec4 ty= texture( iChannel3, pos/16.012 + fract( floor(vec2(c, 15.999-c/16.012)) / 16.012 ) )/3.0 ;
  
    vec4 tz= texture( iChannel2,pos);
    
    return  vec4((tx+ty)/(tz*3.0));
    // possible variants: (but better separated in an upper function) 
    //     - inout pos and include pos.x -= .5 + linefeed mechanism
    //     - flag for bold and italic 
}

bool is_inf(float val) {
#if __VERSION__ >= 300
    return isinf(val);	//webGL 2.0 is required
#else
	return val != val;
#endif
}

vec3 getBallTexture(vec2 uv, vec3 color, bool solid, int number) {
    uv = uv.yx;
    
    //const float PI = 3.1415926;
    //const float HPI = PI * 0.5;
    //uv -= vec2(0.5);
    //uv /= vec2(cos(uv.x*HPI), cos(uv.y*HPI));
    //uv /= vec2(2.0,3.0);
    //uv += vec2(0.5);
    
    vec2 dirToCenter = vec2(0.5, 0.5) - vec2(uv.x + (0.5-uv.x)*0.5, uv.y);
    float d = sqrt(dot(dirToCenter, dirToCenter));
    vec3 white = vec3(1.0, 1.0, 0.9);
    float edgeBlend = 0.003;
    float r = 0.07;
    
    if(d > r + edgeBlend) {
        if(solid) {
            return color;
        } else {
            d = abs(uv.x - 0.5);
            if(d < 0.18 - edgeBlend) {
                return color;
            } else if(d > 0.18 + edgeBlend) {
                return white;
            } else {
                vec3 c = texture(iChannel2,uv*1.5).xyz;
                
                float dirt= length(c);
                float blend = ((d - (0.18 - edgeBlend))/(2.0*edgeBlend))*dirt;
        		return mix(color, white, blend);
            }
        }
    } else if(d < r - edgeBlend){
        vec2 scale = vec2(5.0, 8.0);
        vec4 num = char(uv*scale - 0.5*scale + vec2(0.5), 48.0 + float(number));
        num.xyz = vec3(1.0) - num.xxx*2.0;
        return mix(white, num.xyz, num.w);
    } else {
        vec3 c = texture(iChannel2,uv*1.5).xyz;
        float dirt= length(c);
        float blend = ((d - (r - edgeBlend))/(2.0*edgeBlend))*dirt;
        return mix(white, color, blend);
    }
}

vec3 getCueTexture(vec2 uv) {
    vec3 wood = texture( iChannel1, uv.yx ).xyz;
    
    if(uv.y > 1.0)
        return wood;
    
    float k = fract(uv.x / 0.2);
    
    if(k < 0.5) {
        return wood * (((0.5-k)*0.4 < uv.y-0.5)?vec3(1.0):vec3(0.01));
    }else {
        return wood * (((k-0.5)*0.4 < uv.y-0.5)?vec3(1.0):vec3(0.01));
    }
}

vec3 getCueNormal(vec2 uv) {
    const float heightScale = 0.004;

    vec2 res = vec2(256.0, 256.0);
    vec2 duv = vec2(1.0) / res.xy;
    vec3 c  = getCueTexture( uv).xyz;
    vec3 c1 = getCueTexture( uv + vec2(duv.x, 0.0)).xyz;
    vec3 c2 = getCueTexture( uv - vec2(duv.x, 0.0)).xyz;
    vec3 c3 = getCueTexture( uv + vec2(0.0, duv.y)).xyz;
    vec3 c4 = getCueTexture( uv - vec2(0.0, duv.y)).xyz;
    
    float h0	= heightScale * dot(c , vec3(1.0/3.0));
    float hpx = heightScale * dot(c1, vec3(1.0/3.0));
    float hmx = heightScale * dot(c2, vec3(1.0/3.0));
    float hpy = heightScale * dot(c3, vec3(1.0/3.0));
    float hmy = heightScale * dot(c4, vec3(1.0/3.0));
    float dHdU = (hmx - hpx) / (2.0 * duv.x);
    float dHdV = (hmy - hpy) / (2.0 * duv.y);
    
    return normalize(vec3(dHdU, dHdV, 1.0));
}

// random number generator **********
// taken from iq :)
float seed;	//seed initialized in main
float rnd() { return fract(sin(seed++)*43758.5453123); }
//***********************************

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    seed = iTime + iResolution.y * fragCoord.x / iResolution.x + fragCoord.y / iResolution.y;
    
    vec2 uv = (fragCoord.xy + vec2(rnd(),rnd())) / iResolution.xy;
    if(uv.x > 0.9 && uv.y > 0.6) {
        //uv = clamp(uv, vec2(0.9, 0.6), vec2(1.0));
        vec2 uv2 = uv*2.0 - 1.0;
        uv2.x*= iResolution.x/iResolution.y;
        uv2.x *= 0.97;
        uv2.y *= 1.13;

        vec3 campos = vec3(uv2, 10.0);
        vec3 ray = vec3(0.0, 0.0, -1.0);
        vec2 t = trace(campos, ray, maxdist);
        float tx = t.x;
        vec3 col;
        vec3 n = vec3(0.0, 0.0, 1.0);

        if (tx<maxdist)
        {
            vec3 pos = campos + tx*ray;

            if (abs(pos.x)>clsize || abs(pos.y)>clsize)
                n = vec3(0.0, 0.0, 1.0);

            n = getNormal(pos, normdelta, t.y);
        }

        if(uv.y > 0.8){
            n.y = -n.y;
    		n.z += 0.1;
        	fragColor = vec4((n+vec3(1.0))*0.5,1.0);
        } else {
            float depth;
            if (tx<maxdist) {
                depth = (1.0 - ((tx - 9.95) * 15.0));//*n.z;
            } else {
                depth = 0.03;
            }
            
            vec3 green = vec3(0.2, 1.0, 0.3)*depth;
            if(depth > 0.6) {
            	vec3 yellow = vec3(0.5, 6.0, 0.2)*0.35;
                green = mix(green, yellow, max(0.0, depth - 0.6)/0.4);
            }
            
            fragColor = vec4(green,1.0);
        }
    } else if(uv.x > 0.6 && uv.y > 0.6) {
        uv.x -= 0.6;
        uv.y -= 0.6;
        uv /= vec2(0.3, 0.4);
        fragColor = vec4(getBallTexture(uv, vec3(0.0, 0.1, 0.4), false, 1),1.0);
    } else if(uv.x > 0.3 && uv.y > 0.6) {
        uv.x -= 0.3;
        uv.y -= 0.6;
        uv /= vec2(0.3, 0.4);
        fragColor = vec4(getBallTexture(uv, vec3(0.5, 0.0, 0.0), false, 8),1.0);
    } else if(uv.y > 0.6) {
        uv.y -= 0.6;
        uv /= vec2(0.3, 0.4);
        fragColor = vec4(getBallTexture(uv, vec3(0.6, 0.6, 0.1), true, 3),1.0);
    } else if(uv.y > 0.3) {
        uv.y -= 0.3;
        uv /= vec2(1.0, 0.3);
        fragColor = vec4(getCueTexture(uv.yx),1.0);
    } else  {
        uv.y -= 0.3;
        uv /= vec2(1.0, 0.3);
        fragColor = vec4((getCueNormal(uv.yx)+vec3(1.0))*0.5,1.0);
    }
}

// "Primes as waves" by nimitz 2024
// https://www.shadertoy.com/view/MXdXDN

/*
    An alternate definition of this graph:
        Given a range, how many sine waves of integer half-period (except 1) 
        are required to be able to intersect y=0 at every integer.
*/

#define SHOW_DIGITS
//#define POSITIVE_ONLY

int primes[100] = int[](2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, 223, 227, 229, 233, 239, 241, 251, 257, 263, 269, 271, 277, 281, 283, 293, 307, 311, 313, 317, 331, 337, 347, 349, 353, 359, 367, 373, 379, 383, 389, 397,
                        401, 409, 419, 421, 431, 433, 439, 443, 449, 457, 461, 463, 467, 479, 487, 491, 499, 503, 509, 521, 523, 541);


#define pi 3.14159265358979
float sign2(float x){return x>=0.0?1.0:-1.0;}

float dr(float v, float num)
{
    #ifdef POSITIVE_ONLY
    return abs(sign2(num)*-sin(v*pi / num)*pow(abs(num),1.)*0.1*sign2(num));
    #else
    return sign2(num)*-sin(v*pi / num)*pow(abs(num),.9)*0.1*sign2(num);
    #endif
}

float draw(const in vec2 p, const in float num)
{
    float v = dr(p.x, num)-p.y;
    float g = 0.5 + dr(p.x + 0.1, num) - dr(p.x- 0.1, num);
    float d = abs(v)/sqrt(g);
    return .001/(d*d + 0.0001);
}

vec3 wheel( vec3 c )
{
    vec3 rgb = vec3(0);
    c.x *= 3.14159265358979;
    rgb.r = pow(abs(cos(c.x - 0.1)),4.)*1.5;
    rgb.g = pow(abs(cos(c.x + 2.0944 + 0.1)),3.);
    rgb.b = pow(abs(cos(c.x + 1.0472 + 0.35)),4.);
    
	return clamp(c.z * mix( vec3(1.0), rgb, c.y),0.,1.);
}

//for codes see: https://www.shadertoy.com/view/ldSBzd
float getChar(vec2 p, int char)
{
	vec2 pos = vec2(char%16, 15 - char / 16);
	pos += clamp(p, 0.001, 0.999);
	return textureLod(iChannel0, pos/16., 0.).r;
}
#define chr(A) col += getChar(pp, A)*0.4,pp.x-=0.5

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    float px = 1.5/iResolution.y;
    vec2 p = (fragCoord - iResolution.xy*.5)/iResolution.y;
    vec2 bp = p;
    float asp = iResolution.x/iResolution.y;
    
    p.x += iTime*0.1 - 1.5;
    p = p*vec2(36.,12.) + vec2(30., 0);

    vec3 col = vec3(0.05);
    
    for(int i = 0; i<100; i++)
    {
        float fi = float(i);
        vec3 col2 = draw(p, float(primes[i]))*step(float(primes[i]), p.x)*wheel( vec3(fi*0.0748, cos(fi*0.65)*0.07+0.9, 0.6));
        col += col2 * smoothstep(.5,0., pow(float(i),1.01) - iTime*2.5 + .75*p.x/pow(float(i+1),.08));
    }
    
    //Axes
    col += smoothstep(0.07,.0,abs(fract(p.x + 0.5)-0.5))*0.05;
    col += smoothstep(0.07,.0,abs(fract(p.y + 0.5)-0.5))*0.05;
    col *= smoothstep(0.0,0.1, abs(p.x));
    col += smoothstep(0.03,0.0, abs(p.y))*0.9;
    
#ifdef SHOW_DIGITS
    vec2 pp = bp;
    pp = (p - vec2(-0.4,-1.6))*1.;
    chr(48); // 0
    pp = (p - vec2(-0.5 + 5.2, -1.6))*1.;
    chr(53);  // 5
    pp = (p - vec2(-0.5 + 11., -1.6))*1.;
    chr(49);chr(49);  // 11
    pp = (p - vec2(-0.5 + 50., -1.6))*1.;
    chr(53);chr(48);  // 11
    pp = (p - vec2(-0.7 + 100.01, -4.))*1.;
    chr(49);chr(48);chr(48); // 100
    pp = (p - vec2(-0.7 + 200., -5.))*1.;
    chr(50);chr(48);chr(48); // 200
#endif

    fragColor = vec4(pow(col,vec3(0.45)),1.0);
}

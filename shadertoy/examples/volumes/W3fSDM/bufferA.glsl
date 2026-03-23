// https://www.shadertoy.com/view/fsSSzw
// galaxy ripple nebula effect
//#define PROCEDURAL_HASH

#ifdef PROCEDURAL_HASH
vec3 hash33(vec3 p)
{
    const float UIF = (1.0/ float(0xffffffffU));
    const uvec3 UI3 = uvec3(1597334673U, 3812015801U, 2798796415U);
    uvec3 q = uvec3(ivec3(p)) * UI3;
	q = (q.x ^ q.y ^ q.z)*UI3;
	return vec3(q) * UIF;
}
#else
vec3 hash33( vec3 x )
{
	return texture( iChannel0, (x.xy+vec2(3.0,1.0)*x.z+0.5)/256.0, -100.0 ).xyz;
}
#endif


// 3D Voronoi- (IQ)
float voronoi(vec3 p){

	vec3 b, r, g = floor(p);
	p = fract(p);
	float d = 1.; 
	for(int j = -1; j <= 1; j++)
    {
	    for(int i = -1; i <= 1; i++)
        {
		    b = vec3(i, j, -1);
		    r = b - p + hash33(g+b);
		    d = min(d, dot(r,r));
		    b.z = 0.0;
		    r = b - p + hash33(g+b);
		    d = min(d, dot(r,r));
		    b.z = 1.;
		    r = b - p + hash33(g+b);
		    d = min(d, dot(r,r));
	    }
	}
	return d;
}

// fbm layer
float noiseLayers(in vec3 p) {

    vec3 pp = vec3(0., 0., p.z + iTime*.05);
    float t = 0.;
    float s = 0.;
    float amp = 1.;
    for (int i = 0; i < 5; i++)
    {
        t += voronoi(p + pp) * amp;
        p *= 2.;
        pp *= 1.5;
        s += amp;
        amp *= .5;
    }
    return t/s;
}

mat2 rot( float th ){ vec2 a = sin(vec2(1.5707963, 0) + th); return mat2(a, -a.y, a.x); }
#define TWO_PI 6.2831853


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 uv = (fragCoord.xy - 0.5 * iResolution.xy) / iResolution.y;
        float dd = length(uv*uv)*.025;
    
	vec3 rd = vec3(uv.x, uv.y, 1.0);
    
    float rip = 0.5+sin(length(uv)*20.0+iTime)*0.5;
    rip = pow(rip*.38,4.15);
    rd.z=1.0+rip*1.15;// apply a subtle ripple
    rd = normalize(rd);
    rd.xy *= rot(dd-iTime*.025);
    rd*=2.0;
	
	float c = noiseLayers(rd*1.85);
    float oc = c;
    c = max(c + dot(hash33(rd)*2. - 1., vec3(.006)), 0.);
    c = pow(c*1.55,2.5);    
    vec3 col =  vec3(.55,0.5,1.25);
    vec3 col2 =  vec3(1.95,0.95,1.4)*5.0;
    float pulse2 = voronoi(vec3((rd.xy*1.5),iTime*.255));
    float pulse = pow(oc*1.35,4.0);
    col = mix(col,col2,pulse*pulse2)*c;
    
    if (iMouse.z>0.5)
        col = col.yxz;
    fragColor = vec4(sqrt(col),1.0);
}

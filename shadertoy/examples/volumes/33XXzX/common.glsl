float saturate(in float f) { return clamp(f, 0.,1.); }
vec2 saturate(in vec2 f) { return clamp(f, 0.,1.); }
vec3 saturate(in vec3 f) { return clamp(f, 0.,1.); }
vec4 saturate(in vec4 f) { return clamp(f, 0.,1.); }
float unmix(in float a, in float b, in float t) { return (t-a)/(b-a); }
vec2 unmix(in vec2 a, in vec2 b, in vec2 t) { return (t-a)/(b-a); }
vec3 unmix(in vec3 a, in vec3 b, in vec3 t) { return (t-a)/(b-a); }
vec4 unmix(in vec4 a, in vec4 b, in vec4 t) { return (t-a)/(b-a); }

// axis aligned box centered at the origin, with size boxSize
vec2 boxIntersection( in vec3 ro,in  vec3 rd, in vec3 boxSize ) 
{
    vec3 m = 1.0/rd; // can precompute if traversing a set of aligned boxes
    vec3 n = m*ro;   // can precompute if traversing a set of aligned boxes
    vec3 k = abs(m)*boxSize;
    vec3 t1 = -n - k;
    vec3 t2 = -n + k;
    float tN = max( max( t1.x, t1.y ), t1.z );
    float tF = min( min( t2.x, t2.y ), t2.z );
    if( tN>tF || tF<0.0) return vec2(-1.0); // no intersection
    return vec2( tN, tF );
}

float mrand (vec3 v) {
    return fract(sin(dot(v,
                         vec3(12.9898,78.233,23.42345)))*43758.5453123);
}
// polynomial smooth min (k = 0.1);
float smin( float a, float b, float k )
{
    float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
    return mix( b, a, h ) - k*h*(1.0-h);
}
float gain(float x, float k) 
{
    float a = 0.5*pow(2.0*((x<0.5)?x:1.0-x), k);
    return (x<0.5)?a:1.0-a;
}
float gain4(float x) 
{
    float pw = 2.0*((x<0.5)?x:1.0-x);
    pw*=pw;// 2
    pw*=pw;// 4
    float a = 0.5*pw;
    return (x<0.5)?a:1.0-a;
}
float gain8(float x) 
{
    float pw = 2.0*((x<0.5)?x:1.0-x);
    pw*=pw;// 2
    pw*=pw;// 4
    pw*=pw;// 8
    float a = 0.5*pw;
    return (x<0.5)?a:1.0-a;
}
float xyPlaneLine(vec3 point, vec2 from, vec2 to)
{
    vec2 del = to-from;
    float len = length(del);
    vec2 ndl = (1./len)*del;
    float dt = dot(point.xy - from,ndl);
    return length(point-vec3(from+clamp(dt,0.,len)*ndl,0.));
}

float remap1(in float fa, in float fb, in float ta, in float tb, in float t)
{
    return mix(ta, tb, (t - fa) / (fa - fb));
}

vec2 remap2(in vec2 fa, in vec2 fb, in vec2 ta, in vec2 tb, in vec2 t)
{
    return mix(ta, tb, (t - fa) / (fa - fb));
}

vec2 unmix2(in vec2 a, in vec2 b, in vec2 t)
{
    return (t-a)/(b-a);
}


float mnoise (in vec3 p, in float repeat) {
    float mn = 99999.;
    vec3 bas = floor(p), cur, off;
    
    cur = bas + vec3(-1., -1., -1.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3(-1., -1.,  0.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3(-1., -1.,  1.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3(-1.,  0., -1.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3(-1.,  0.,  0.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3(-1.,  0.,  1.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3(-1.,  1., -1.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3(-1.,  1.,  0.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3(-1.,  1.,  1.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3( 0., -1., -1.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3( 0., -1.,  0.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3( 0., -1.,  1.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3( 0.,  0., -1.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3( 0.,  0.,  0.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3( 0.,  0.,  1.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3( 0.,  1., -1.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3( 0.,  1.,  0.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3( 0.,  1.,  1.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3( 1., -1., -1.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3( 1., -1.,  0.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3( 1., -1.,  1.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3( 1.,  0., -1.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3( 1.,  0.,  0.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3( 1.,  0.,  1.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3( 1.,  1., -1.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3( 1.,  1.,  0.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    cur = bas + vec3( 1.,  1.,  1.); off = cur + mrand(mod(cur, repeat)) - p; mn = min(mn, dot(off, off));
    
    return clamp(1.-.707701*sqrt(mn),0.,1.);
}

float fbm(in vec3 p, in float repeat, in float scale) {
	float noi = .5  * mnoise(p * 1.00 * scale, scale)
             + .31 * mnoise(p * 2.00 * scale, 2.0 * scale)
             + .21 * mnoise(p * 4.00 * scale, 4.0 * scale);
    noi /= 1.02;
    return noi;    
}


vec3 two2three(in vec2 uv, in vec2 res)
{
    vec2 rr = 8.*floor(res*.125);
    uv *= res/rr;
    float z = .125*floor(uv.y*8.)+0.015625*floor(uv.x*8.);
    vec2 hp = 4./rr;
    vec2 xy = unmix(hp, 1.-hp,fract(uv*8.));
    return vec3(xy, z);
}
vec2 three2two(in vec3 p, in vec2 res, out float partialZ)
{
    float z64 = p.z*64.;
    partialZ = fract(z64);
    float enc = floor(z64)*.125;
    vec2 ints = vec2(fract(enc),.125*floor(enc));    
    vec2 rr = 8.*floor(res*.125);
    vec2 ehp = .5/rr;
    return (rr/res)*(ints+mix(ehp,.125-ehp,p.xy));
}

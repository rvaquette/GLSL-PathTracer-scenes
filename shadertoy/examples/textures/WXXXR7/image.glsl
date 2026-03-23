#define MAX_DIST 100.
#define SURF_DIST .001
#define EPS .0001
#define PI 3.14
#define PI2 6.28
#define saturate(a) clamp(a,0.,1.)
#define S(a,b,t) smoothstep(a,b,t)
#define TS(a,b,c,d,t) smoothstep(a,b,t) * smoothstep(d,c,t)
#define REP(p,r) mod(p,r) - r * .5  

#define MAT_BALL 1.
#define MAT_FLOOR 2.
#define MAT_WALL 3.

#define CT iTime * .22 + .22
// #define CP vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.33,0.67)
#define CP vec3(1.,1.,1.),vec3(2., .8, .4),vec3(.8,1.0,2.0),vec3(.52,0.,.2)

// ref: https://www.shadertoy.com/view/ll2GD3
vec3 palette( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d ) {
    return a + b*cos( 6.283185*(c*t+d) );
}

vec3 getLightColor() {
    return palette(CT, CP * .98) * 1.;
}

vec3 getBallBaseColor() {
    return palette(CT, CP * 1.01) * .35;
}

vec3 getBallEmissionColor() {
    return palette(CT, CP * 1.02) * .5;
}

float rand(vec2 co){
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

mat2 rot(float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}

float sdSphere(vec3 p, float s) {
    return length(p) - s;
}

float sdPlane( vec3 p, vec3 n, float h ) {
  return dot(p,n) + h;
}

float opUnion(float d1, float d2) {
    return min(d1, d2);
}

vec2 opUnion2(vec2 a, vec2 b) {
	return a.x < b.x ? a : b;
}

float opSmooth(float d1, float d2, float k)
{
    float h = clamp(.5 + .5 *(d2 - d1) / k, 0., 1.);
    return mix(d2, d1, h) - k * h * (1. - h);
}

//------------

// ref:
// Noise - gradient - 2D 
// pkhttps://www.shadertoy.com/view/XdXGW8

vec2 grad( ivec2 z )  // replace this anything that returns a random vector
{
    // 2D to 1D  (feel free to replace by some other)
    int n = z.x+z.y*11111;

    // Hugo Elias hash (feel free to replace by another one)
    n = (n<<13)^n;
    n = (n*(n*n*15731+789221)+1376312589)>>16;

#if 0

    // simple random vectors
    return vec2(cos(float(n)),sin(float(n)));
    
#else

    // Perlin style vectors
    n &= 7;
    vec2 gr = vec2(n&1,n>>1)*2.0-1.0;
    return ( n>=6 ) ? vec2(0.0,gr.x) : 
           ( n>=4 ) ? vec2(gr.x,0.0) :
                              gr;
#endif                              
}

// -1 ~ 1
float noise( in vec2 p )
{
    ivec2 i = ivec2(floor( p ));
     vec2 f =       fract( p );
	
	vec2 u = f*f*(3.0-2.0*f); // feel free to replace by a quintic smoothstep instead

    return mix( mix( dot( grad( i+ivec2(0,0) ), f-vec2(0.0,0.0) ), 
                     dot( grad( i+ivec2(1,0) ), f-vec2(1.0,0.0) ), u.x),
                mix( dot( grad( i+ivec2(0,1) ), f-vec2(0.0,1.0) ), 
                     dot( grad( i+ivec2(1,1) ), f-vec2(1.0,1.0) ), u.x), u.y);
}


// ref: https://www.shadertoy.com/view/ldSGzR

vec3 doBump( in vec3 pos, in vec3 nor, in float signal, in float scale )
{
    vec3 dpdx = dFdx( pos );
    vec3 dpdy = dFdy( pos );
    
    float dbdx = dFdx(signal);
    float dbdy = dFdy(signal);

    vec3  u = cross( dpdy, nor );
    vec3  v = cross( nor, dpdx );
    float d = dot( dpdx, u );
	
	vec3 surfGrad = dbdx*u + dbdy*v;
    return normalize( abs(d)*nor - sign(d)*scale*surfGrad );
}


// -----------

vec2 scene(vec3 p) {
    vec2 res = vec2(100000., -1.);
    float t = iTime;
    
    vec3 q = p;

    vec2 obj = res;

    vec3 qb = q;
    qb -= vec3(0., 2.3, -1.);
    vec2 objb = res;
    float db = 10000.;
    for(float i = 0.; i < 8.; i++) {
        vec3 qbo = vec3(
            sin(t * (.95 + sin(i)) + i * 10.) * 2.4,
            cos(t * (.9 + cos(i)) + i * 40.) * .9,
            sin(t * (1.2 + cos(i)) + i * 30.) * 1.4
        );
        float d  = sdSphere(qb - qbo, .65 + sin(i) * .32);
        db = opSmooth(db, d, .8);
    }
    objb = opUnion2(objb, vec2(db, MAT_BALL));
    
    res = opUnion2(res, objb);

    // floor
    res = opUnion2(
        res,
        vec2(sdPlane(q, vec3(0., 1., 0.), 0.), MAT_FLOOR)
    );

    // back wall
    res = opUnion2(
        res,
        vec2(sdPlane(q, vec3(0., 0., -1.), 15.), MAT_WALL)
    );
    
    return res;
}

vec3 getNormal(vec3 p) {
	vec2 e = vec2(1., -1.) * EPS;
    return normalize(
        e.xyy * scene(p + e.xyy).x+
        e.yxy * scene(p + e.yxy).x+
        e.yyx * scene(p + e.yyx).x+
        e.xxx * scene(p + e.xxx).x
    );
}

vec2 raymarch(vec3 ro, vec3 rd, float io, float distO, float side, inout vec3 emission) {
    float accDist = io;    
    float mat = 0.;

    for(int i = 0; i < 99; i++) {
        vec3 p = ro + rd * accDist;
        vec2 result = scene(p);
        float dist = result.x * side;
        mat = result.y;
        if(abs(dist) < SURF_DIST || accDist >= MAX_DIST) {
            break;
        }
        dist *= distO; // opt
        accDist += dist;                
        
        if(mat == MAT_BALL) {
            // emission += (.01 / abs(dist)) * GLOW_EMISSION_COLOR;
            emission += exp(abs(dist) * -20.) * getBallEmissionColor();
        }
    }
    
    return vec2(accDist, mat);
}


vec3 getRayDir(vec2 uv, vec3 p, vec3 l, float z) {
    vec3 forward = normalize(l - p);
    vec3 right = normalize(cross(vec3(0., 1., 0.), forward));
    vec3 up = normalize(cross(forward, right));
    
    return normalize(right * uv.x + up * uv.y + forward * z);        
}

vec4 getBumpNormal(vec3 pos, float l, float bump) {
    vec3 nor = vec3(0., 1., 0.);
    vec3 mate = texture( iChannel0, 0.25*pos.zx, .1*l ).xyz;
    float signal = dot(mate,vec3(0.33));
    nor = doBump( pos, nor, signal, 0.15*bump );
    return vec4(nor, signal);
}

float getSpecular(vec3 P, vec3 N, vec3 L, vec3 E, float power) {
    vec3 PE = normalize(E - P);
    vec3 H = (PE + normalize(L)) * .5;
    float NoH = saturate(dot(N, H));
    return pow(NoH, power);
}

float calcAO(vec3 p, vec3 n) {
  float k = 1.;
  float occ = 0.;
  for(int i = 0; i < 5; i++) {
    float len = .15 * (float(i) + 1.);
    float d = scene(n * len + p).x;
    occ += (len - d) * k;
    k *= .5;
  }
  return clamp(1. - occ, 0., 1.);
}


// ref:
// https://www.shadertoy.com/view/lsKcDD
const int maxShadowIterations = 32;
float softShadow(vec3 ro, vec3 rd, float mint, float tmax, float power) {
  float res = 1.;
  float t = mint;
  float ph = 1e10;
  for(int i = 0; i < maxShadowIterations; i++) {
    float h = scene(ro + rd * t).x;

    // pattern 1
    res = min(res, power * h / t);

/*
    // pattern 2
    float y = h * h / (2. * ph);
    float d = sqrt(h * h - y * y);
    res = min(res, power * d / max(0., t - y));
    ph = h;
*/

    t += h;

    float e = EPS;
    if(res < e || t > tmax) break;
  }
  res = clamp(res, 0., 1.);

  return res*res*(3.0-2.0*res);
}

float fresnel(vec3 p, vec3 n, vec3 e) {
    vec3 ep = normalize(e - p);
    float f = pow(1. - saturate(dot(ep, n)), 2.) * .7 + .3;
    return f;
}

vec3 renderGlow(vec3 p, vec3 n, vec3 e, vec3 l, float ss, float ao, inout vec3 emission) {
    float diffuse = 0.;
    vec3 col = vec3(0.);
 
    float f = fresnel(p, n, e);
 
    diffuse = dot(l, n) * .5 + .5;
    col +=
        vec3(diffuse) * getLightColor() * getBallBaseColor()
         * ss
         * ao
         * f
         ;
         
     emission *= f;
         
    return col;
}

vec3 renderFloor(vec2 uv, vec3 p, vec3 n, vec3 r, vec3 l, vec3 e, float ss, float ao, float bump, inout vec3 refEmission) {
        float t = iTime;

        float diffuse = dot(l, n) * .5 + .5;
        
        float t1 = noise(.6 * p.xz - vec2(4., 1.));      
        float nt1 = t1 * .5 + .5;
        float wr1 = smoothstep(.48, .62, pow(nt1, .8));

        float t2 = noise(9. * p.xz);      
        float nt2 = pow(t2 * .5 + .5, .2);
        float wr2 = .5 + nt2 * .5;
            
        float specular = getSpecular(p, n, l, e, 8.);

        vec3 col =
            (vec3(diffuse) * getLightColor() * (1. - wr1) * vec3(.8, .75, .7) * wr2 +
            specular * (1. - wr1) * getLightColor() * getBallEmissionColor())
            * ss
            * ao;

        float refR = saturate(wr1) * .09 + saturate(bump) * specular * .1; // fake specular

        // distort
        r += t1 * (.08 + bump * .025 + sin(uv.x + uv.y * 50. + t * 2.) * .02);
        r = normalize(r);

        vec3 rrOff = (vec3(rand(uv)) * 2. - 1.) * .01;
        vec3 pro = p + r * .05 + rrOff;
        vec2 rr = raymarch(pro, r, 0., .4, 1., refEmission);
        float rDist = rr.x;
        float rMat = rr.y;
        
        vec3 em = vec3(0.);
        
        float f = 1.;
        
        if(rDist < MAX_DIST) {
            vec3 rp = p + r * rDist;
            vec3 rn = getNormal(rp);
            if(rMat == MAT_BALL) {
                f = fresnel(rp, rn, pro);
                col += renderGlow(p, rn, e, l, ss, ao, em) * refR;
            }
            // for debug
            // col = r;
        }
        
        refEmission *= refR * f;

        return col;
}
 

// --------------------------------------------------

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    float t = iTime;

    vec2 uv = (fragCoord.xy * 2. - iResolution.xy) / min(iResolution.x, iResolution.y);

    vec2 m = (iMouse.xy * 2. - iResolution.xy) / min(iResolution.x, iResolution.y);
    vec3 ro = vec3(
        m.x * 2.,
        m.y * 2. + 2.4,
        -6.4
    );

    vec3 rd = getRayDir(uv, ro, vec3(0., .9, 0.), 1.55);
    
    vec3 emission = vec3(0.);
    vec3 refEmission = vec3(0.);
    
    vec2 result = raymarch(ro, rd, 0., .35, 1., emission);
    float dist = result.x;
    float mat = result.y;
    
    vec3 col = vec3(0.);
    
    float f = 1.;
    
    if(dist < MAX_DIST) {    
        vec3 p = ro + rd * dist;
        vec3 l = normalize(vec3(.4, 1., .1));
        vec3 n = getNormal(p);    
        vec3 r = reflect(rd, n);

        float diffuse = 0.;
        
        float ss = softShadow(p, normalize(l), .1, 28., 8.) * .75 + .25; // adjust
        float ao = calcAO(p, n);        
        
        if(mat == MAT_BALL) {
            f = fresnel(p, n, ro);
            col += renderGlow(p, n, ro, l, ss, ao, emission);
        } else if(mat == MAT_FLOOR) {
            vec4 bump = getBumpNormal(p, .1, .6);
            vec3 n = bump.xyz;
            float bp = bump.w;
            float bpa = bp * 2. - 1.;                
            col += renderFloor(uv, p, n, r, l, ro, ss, ao, bpa, refEmission);    
        }
    }
    
    col += emission * vec3(f);
    col += refEmission;
    
    // cheap ambient
    // col += BALL_EMISSION_COLOR * .04;
    col += getBallEmissionColor() * .04;
    
    col *= exp(-dist * .25);
        
    col = pow(col, vec3(.4545));
    
    col *= 1. - smoothstep(1.2, 2.4, length(uv));
    
    fragColor = vec4(col, 1.);
}


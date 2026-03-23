
#define PI 3.14159265359

// IQ https://www.shadertoy.com/view/ll2GD3
vec3 pal( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d ) {
    return a + b*cos( 6.28318*(c*t+d) );
}

vec3 spectrum(float n) {
    return pal( n, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.33,0.67) );
}

void pR(inout vec2 p, float a) {
    p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

float vmax(vec3 v) {
    return max(max(v.x, v.y), v.z);
}

float fBox(vec3 p, vec3 b) {
    vec3 d = abs(p) - b;
    return length(max(d, vec3(0))) + vmax(min(d, vec3(0)));
}

// Read head sdf from '3D' texture
float mHead(vec3 p) {
    p.x = -abs(p.x);
    p += OFFSET / SCALE;
    float bound = fBox(p, 1./SCALE);
    if (bound > .01) return bound;
    p *= SCALE;
    float d = mapTex(iChannel0, p, iChannelResolution[0].xy);
    return d;
}

float sinstep(float t) {
	return sin(t * PI + PI * .5) * .5 + .5;
}

float map(vec3 p) {
    p.y -= .06;
    
    vec2 im= iMouse.xy / iResolution.xy;
    im= vec2(.38,.6);
    
    if (im.x > 0. && im.y > 0.) {
    	pR(p.zx, ((im.x)*2.-1.)*1.5);
    	pR(p.zy, ((im.y)*2.-1.)*1.5);
    }

    float r = sin(1. * fTime * PI * 2. - PI * .6);
    r = smoothstep(0., 1., clamp((r - .4) * .7, -1., 1.) * .5 + .5);
    float t = mod(fTime - .2, 1.);
    r = sinstep(range(.05, .45, fTime)) - sinstep(range(.45, 1., fTime));
    r = r * .05;
    pR(p.zy, -r);

    float d = mHead(p);
    return d;
}


#define ZERO (min(iFrame,0))

// https://iquilezles.org/articles/normalsSDF
vec3 calcNormal( in vec3 pos )
{
    vec3 n = vec3(0.0);
    for( int i=ZERO; i<4; i++ )
    {
        vec3 e = 1.5773*(2.0*vec3((((i+3)>>1)&1),((i>>1)&1),(i&1))-1.0);
        n += e*map(pos+0.001*e);
    }
    return normalize(n);
}

const float DISPERSION_SAMPLES = 3.; // Higher = slower but smoother blending

vec3 drawBg(vec3 rd) {
    float t = atan(rd.y, rd.z);
    t = sin(t * 15. - fTime * PI * 2.);
	vec3 c = vec3(smoothstep(-.2, .0, -1. + t)) * 2.;
    return c;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    
    vec2 p = (-iResolution.xy + 2. * fragCoord.xy) / iResolution.y;
    vec3 col = vec3(0.);

    if (iMouse.z > 0.) {
    	p /= 1.8;
    }

    p /= 1.15;
    
    float wavelength;
    vec3 pos;
    vec3 nor;
    vec3 rrd;
    float ri;
    vec3 sam;

    float rand = texture(iChannel1, fragCoord.xy / iChannelResolution[1].xy).r;
    rand = fract(rand + 1.61803398875 * float(iFrame)); // https://blog.demofox.org/2017/10/31/animating-noise-for-integration-over-time/

    vec3 origin = vec3(0,.05,3.2);
    vec3 rd = normalize(vec3(p + vec2(0,-0),-4));
    float rayLength = 0.;
    float dist = 0.;

    for (int i = 0; i < 50; i++) {
        rayLength += dist;

        pos = origin + rd * rayLength;
        dist = map(pos);

        if (dist < .0005) {
            nor = calcNormal(pos);

            for(float r = 0.; r < DISPERSION_SAMPLES; r++){
                wavelength = r / DISPERSION_SAMPLES;
                wavelength += (rand * 2. - 1.) * (.5 / DISPERSION_SAMPLES);
                wavelength = mod(wavelength, 1.);

                ri = 1.3 + (wavelength - .5) * .9;
                ri = 1. / ri;
                rrd = refract(rd, nor, ri);
                col += drawBg(rrd) * spectrum(wavelength);
            }

            break;
        }

        if (rayLength > 5.) {
            break;
        }
    }

    col /= DISPERSION_SAMPLES / 2.;    
    
    if (iFrame > 2) {
        vec2 uv = fragCoord.xy / iResolution.xy;
        vec3 lastcol = texture(iChannel2, uv).rgb;
        col = mix(lastcol, col, clamp(15. * iTimeDelta, 0., 1.));
    }

    fragColor = vec4(col,1);
}

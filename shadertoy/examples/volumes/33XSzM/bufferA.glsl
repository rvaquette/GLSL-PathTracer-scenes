float material;
float glow;
vec3 mouse;

// fractal brownian motion https://thebookofshaders.com/13/
vec3 fbm (vec3 p)
{
    vec3 result = vec3(.0);
    float a = .5;
    for (float i = 0.; i < 3.; ++i) {
        p.y += iTime*.005/a;
        result += sin(texture(iChannel1, p/a).xyz*6.28)*a;
        a /= 2.;
    }
    return result;
}

// signed distance function
float map(vec3 p)
{
    float dist = 100.;
    float shape = 100.;
    vec3 pp = p;
    float c;
    
    // sphere
    dist = length(p)-1.;
    
    // droplets
    c = pModPolar(p.xz, 8.);
    vec3 rng = hash31(c);
    p.x -= 1.-.5;
    rng.x += sign(p.x)*.5;
    p.x = abs(p.x)-.2;
    p.y *= -1.;
    float time = iTime * .2 + rng.x;
    float anim = fract(time);
    float index = floor(time);
    float wave = sin(anim*3.14);
    float h = .7+.3*pow(wave, 4.);
    float s = .03-.03*(1.-wave);
    shape = sdSegment(p, h, s);
    dist = smin(dist, shape, .2);
    shape = length(p-vec3(0,pow(anim, 10.)*200.+h,0))-.05;
    dist = smin(dist, shape, .3*pow(anim,0.5));
    
    // sphere mouse interaction
    dist = smin(dist, length(pp+mouse)-.1, .6);
    
    // surface details
    vec3 seed = pp*.1;
    vec3 noise = fbm(seed);
    dist -= noise.x*.01;
    
    return dist * .5;
}

void coloring (inout vec3 color, in vec3 pos, in vec3 normal, in vec3 ray, in vec2 uv, in float shade)
{
    // Inigo Quilez color palette
    // https://iquilezles.org/www/articles/palettes/palettes.htm
    vec3 tint = 1.5+.5*cos(vec3(1,.3,6)*6.283+iTime*.2+uv.y*3.);
    
    // lighting
    color = tint * pow(dot(normal, vec3(0,-1,0))*.5+.5, 10.);
    vec3 rf = reflect(ray, normal);
    float top = dot(rf, vec3(0,1,0))*.4+.5;
    float glow = dot(normal, ray)*.7+.5;
    color += vec3(0.7,.2,0.7)*pow(clamp(top,0.,1.), 1.5); // edit sphere color
    color += vec3(4,1,1)*pow(glow, 2.);
    color *= pow(shade,.5);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord-iResolution.xy/2.)/iResolution.y;
    
    // background
    vec3 color = vec3(.2)*smoothstep(2.,.5,length(uv));
    
    // coordinates
    vec3 pos = vec3(0,0,3);
    vec3 at = vec3(0);
    pos.zy *= rot(sin(iTime*.2)*.1);
    vec3 ray = lookAt(pos, at, uv, 1.);
    
    // mouse interaction
    if (iMouse.z > 0.5) {
        vec2 uvm = (iMouse.xy-iResolution.xy/2.)/iResolution.y;
        mouse = vectorAt(pos, at, uvm*2., -1.) * -1.;
    }
    else mouse = vec3(0);
    
    // noise
    //vec3 blue = texture(iChannel0, fragCoord/1024.).xyz;
    //vec3 white = hash33(vec3(fragCoord, iFrame));
    
    // materialing
    material = 0.;
    glow = 0.;
    float maxDist = 4.;
    
    // raymarch
    const float count = 50.;
    float steps = 0.;
    float total = 0.;
    for (steps = count; steps > 0.; --steps) {
        float dist = map(pos);
        if (dist < total/iResolution.y || total > maxDist) break;
        dist *= 0.9+0.1;
        ray += total*.002;
        pos += ray * dist;
        total += dist;
    }
    
    // NuSan https://www.shadertoy.com/view/3sBGzV
    vec2 noff = vec2(.001,0);
    vec3 normal = normalize(map(pos)-vec3(map(pos-noff.xyy), map(pos-noff.yxy), map(pos-noff.yyx)));
    
    // coloring
    float shade = steps/count;
    if (shade > .001 && total < maxDist) {
        coloring(color, pos, normal, ray, uv, shade);
    }
    
    fragColor = vec4(color, 1);
}

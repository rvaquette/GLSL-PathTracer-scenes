#define PARTICLES_CNT 512
#define EMITT_SPEED 5.0

#define rnd1(a) (texture(iChannel0, 256.0 / vec2(a, 0)).rgb - vec3(0.5))
#define grad(v, c, siz) max(1.0 - distance(auv, ha + c) / siz, 0.0) * v
#define ztan(v) max(tan(v), 0.0)

vec3 sparks(int i, vec2 auv, vec2 ha, float t)
{
    float g = grad(1.0, 0.0, 0.5);
    vec2 v = rnd1(i).rg * ztan(t) * vec2(1.0, sin(g) * 0.5);
    return vec3(0.5, 0.3, 0.8) * (grad(g, v, 0.006) * 0.5 +
                                  grad(g, v, 0.025) * 0.1);
}

vec3 implosion(int i, vec2 auv, vec2 ha, float t)
{
    float g = grad(1.0, 0.0, 0.2);
    float st = max(1.0 - tan(t) * g * 10.0, 0.0);
    vec2 v = rnd1(i).rg * st  * g * (1.0 - g);
    return vec3(0.05, 0.3, 0.5) * (grad(1.0, v, 0.005) * 0.9 +
                                   grad(1.0, v, 0.015) * 0.2);
}

vec3 portal(int i, vec2 auv, vec2 ha, float t)
{
    float st = max(1.0 - tan(t), 0.0);
    vec2 v = rnd1(i).rg * st * grad(1.0, 0.0, 0.2) * 3.0;
    return vec3(0.1, 0.8, 0.2) * grad(0.2, v, 0.045) *
                                 (1.0 - grad(1.0, 0.0, 0.25) * 2.0);
}

vec3 meteor(int i, vec2 auv, vec2 ha, float t)
{
    ha.y -= 0.15;
    vec2 v = rnd1(i).rg + vec2((ha.x - auv.x) , 0.3);
    return vec3(0.9, 0.5, 0.2) * grad(0.2, v * ztan(t), 0.018) * grad(1.0, 0.0, 0.35);
}

vec3 signals(int i, vec2 auv, vec2 ha, float t)
{
    vec2 v = rnd1(i).rg * sin(auv - ha) * 20.0 + rnd1(i + 1).rg;
    return vec3(0.9, 0.1, 0.1) * grad(0.5, v * ztan(t), 0.01) * grad(1.0, 0.0, 0.3);
}

vec3 pulsar(int i, vec2 auv, vec2 ha, float t)
{
    float mt = iTime * 10.0;
    vec2 v = rnd1(i).rg * vec2(sin(mt), cos(mt)) * ztan(t);
    return vec3(0.5, 1.0, 1.0) * grad(0.1, v, 0.02) * grad(1.0, 0.0, 0.2);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord/iResolution.xy;
    vec2 a = vec2(iResolution.x / iResolution.y, 1.0);
    vec2 auv = uv * a;
    
    vec3 rgb = texture(iChannel1, uv).rgb;
    for(int x = 0; x < PARTICLES_CNT; x++)
    {
        float t = iTime + rnd1(x * 2).x * EMITT_SPEED;
        
        if(uv.x < 0.33 && uv.y < 0.5)
            rgb += sparks(x, auv, a * vec2(0.165, 0.25), t);
        else if(uv.x < 0.33 && uv.y > 0.5)
            rgb += implosion(x, auv, a * vec2(0.165, 0.75), t);
        else if(uv.x < 0.66 && uv.y > 0.5)
            rgb += meteor(x, auv, a * vec2(0.495, 0.75), t);
        else if(uv.x < 0.66 && uv.y < 0.5)
            rgb += portal(x, auv, a * vec2(0.495, 0.25), t);
        else if(uv.x > 0.66 && uv.y < 0.5)
            rgb += signals(x, auv, a * vec2(0.825, 0.25), t);
        else if(uv.x > 0.66 && uv.y > 0.5)
            rgb += pulsar(x, auv, a * vec2(0.825, 0.75), t);
    }

    // Output to screen
    fragColor = vec4(mix(rgb, vec3(0.0), 0.1), 1.0);
}


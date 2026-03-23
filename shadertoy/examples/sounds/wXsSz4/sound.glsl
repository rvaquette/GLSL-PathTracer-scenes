vec2 f(float a, float b, float t)
{
    t = a * mod(t, b);
    return vec2(cos(t / 1e2), sin(t / 1e2)) * (cos(4. * t) + mix(sin(2. * t), sin(8. * t), .2 * t / a / b)) / 2. * min(.1 * t, 1.) * exp(-t / b / 2e2);
}

vec2 mainSound(int samp, float t)
{
    t -= 2.25;
    
    vec2 tot = vec2(0);
    
    vec4 C;
    
    for(int i = 0; i < 15; i++)
    {
        float T = 4. / (1. - float(i) / 70.);
        
        switch(int(floor(t / T) * T / 20.) % 4)
        {
            case 0:
            case 2: C = vec4(2160, 2025, 1620, 1350); break;
            case 1: C = vec4(1800, 1620, 1350, 1080); break;
            case 3: C = vec4(1440, 1350, 1080, 900); break;
        }
        
        tot += .5 * f(C[i % 4] / exp2(float(i / 4)), T, t);
    }
    
    return smoothstep(-2.25, 0., t) * (tot + f(C.x / 16., 20., t) + f(C.x / 8., 20., t)) * .1;
}
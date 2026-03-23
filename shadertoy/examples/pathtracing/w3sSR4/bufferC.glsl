vec3 tex(vec2 p)
{
    vec4 O = texture(iChannel0, p / R.xy);
    return flimTransform(O.xyz / O.w);
}

int poisson(float expMean)
{
    float p = 1.;
    int i = -1;
    while (p > expMean && i++ < 20) p *= rand;
    return i;
}

const float radius = .06,
            sigmaR = .024,
            blur   = .2;

void mainImage(out vec4 O, vec2 I)
{
    O = vec4(0);
    
    if(iFrame < 2 && SKYTYPE > 1) return;
    
    seed = uvec4(I, iFrame, iTime);
    
    if(texelFetch(iChannel2, ivec2(32, 0), 0).x < .5) O = texelFetch(iChannel1, ivec2(I), 0);
    
    float maxRadius = radius, mu, sigma;
    
    float ag = 1. / ceil(1. / radius);
    
    if (sigmaR > 0.)
    {
        sigma = log(sqr(sigmaR / radius) + 1.);
        mu = log(radius) - .5 * sigma;
        sigma = sqrt(sigma);
        maxRadius = exp(mu + 2. * sigma);
    }
    
    vec2 p = I + blur * gaussian2D() + rand2 - .5;
    
    vec3 col = vec3(0);
    
    ivec4 bound = ivec4((p - maxRadius) / ag, (p + maxRadius) / ag);
    
    bool covered = false;
    
    for (int x = bound.x; x <= bound.z && !covered; x++)
    for (int y = bound.y; y <= bound.w && !covered; y++)
    {
        vec2 pos = ag * vec2(x, y);
        
        vec3 expMean = exp(INVPI / (1. + sqr(sigmaR / radius)) * log(1. - tex(pos)));
        
        pos -= p;
        
        for (int i = 0; i < 3; i++)
        {
            if(col[i] > .5) continue;
            
            seed = uvec4(x, y, i, i);
            
            int nGrain = poisson(expMean[i]);
            
            for (int j = 0; j < nGrain; j++)
            {
                if (dot2(pos + ag * rand2) < sqr(sigmaR > 0. ? min(exp(mu + sigma * gaussian()), maxRadius) : radius))
                {
                    col[i]++;
                    break;
                }
            }
        }
        
        if (col == vec3(1)) covered = true;
    }
    
    if(texelFetch(iChannel2, ivec2(32, 0), 0).x < .5) O = texelFetch(iChannel1, ivec2(I), 0);
    
    O += vec4(col, 1);
}

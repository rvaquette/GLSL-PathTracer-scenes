// Exponential smooth min from IQ
float smin( float a, float b, float k )
{
    k *= 1.0;
    float r = exp2(-a/k) + exp2(-b/k);
    return -k*log2(r);
}

// Signed distance to segment from IQ
float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h )+.1;
}

// Noise texture with higher-order interpolation
float smoothNoise(sampler2D t,vec2 uv)
{
    uv *= 256.;
    
    vec2 f = vec2(smoothstep(0., 1., fract(uv.x)),
                  smoothstep(0., 1., fract(uv.y)));
                  
    float a = textureLod(t, (floor(uv) + vec2(0, 0) + .5) / 256., 0.).r;
    float b = textureLod(t, (floor(uv) + vec2(1, 0) + .5) / 256., 0.).r;
    float c = textureLod(t, (floor(uv) + vec2(0, 1) + .5) / 256., 0.).r;
    float d = textureLod(t, (floor(uv) + vec2(1, 1) + .5) / 256., 0.).r;
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Heightmap for a single cell
float cellHeight(vec2 uv, vec2 cell, float scale)
{
    uv = fract(uv) * 2. - 1.;
    
    vec2 absUv = abs(uv);
    vec2 pointOnEdge = uv / max(absUv.x, absUv.y) + cell;

    float d = smin(sdSegment(absUv, vec2(1, 1), vec2( 1, -1)),
                   sdSegment(absUv, vec2(1, 1), vec2(-1,  1)), 1. / 16.);
                   
    float d2 = pow(d, .6);

    float h = pow(smoothstep(.1, 1., d2), .6);

    h += smoothNoise(iChannel0, mix(uv, pointOnEdge / (5. * scale), .9) / 4.) *
                                      exp(-d * 8.) * pow(scale, .5) / 6.;

    return h / 12.;
}

// Heightmap for the whole surface
float surfaceHeight(vec2 uv, vec2 cell)
{
    uv *= .5;

    // Procedural quadtree-style subdivision
    float scale = 1.;
    vec2 offset = vec2(0);
    for(int i = 0; i < 2; ++i)
    {
        float a = textureLod(iChannel0, (floor(uv) + .5 + offset) / 8., 0.).r;
        if(a < .5)
            break;
        if(fract(uv.x * scale) > .5)
            offset.x += .5 / scale;
        if(fract(uv.y * scale)>.5)
            offset.y += .5 / scale;
        scale *= 2.;
    }

    cell += offset * scale * 2.;

    return cellHeight(uv * scale, cell, scale) / scale * 2.;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - iResolution.xy * 0.5) / iResolution.y * 2.0;
    vec2 uv2 = uv;

    // Rotation
    float a = .2 + iTime / 64.;
    uv *= mat2(cos(a), sin(a), -sin(a), cos(a));

    // Ray direction
    vec3 r = normalize(vec3(uv, -1));

    // Translation
    uv *= 2.;
    uv += iTime / 6.;
    
    vec2 cell = floor(uv * .5) * 2.;

    // Get surface normal from heightmap
    const float eps = 1. / 64.;
    float h0 = surfaceHeight(uv, cell);
    float h1 = surfaceHeight(uv + vec2(eps, 0.), cell);
    float h2 = surfaceHeight(uv + vec2(0., eps), cell);

    vec3 n = normalize(cross(vec3(vec2(eps, 0.), h1 - h0), vec3(vec2(0., eps), h2 - h0)));

    vec3 col = vec3(0);
    vec3 refl = reflect(r,n);
    
    // Specular highlights
    col += vec3(pow(max(0., dot(refl, normalize(vec3(1)))), 32.)) * 4. * vec3(1, 1, .75);
    col += vec3(pow(max(0., dot(refl, normalize(vec3(0, -.2, 1)))), 16.));
    col += vec3(pow(max(0., dot(refl, normalize(vec3(-1, 0, .5)))), 32.)) / 2. * vec3(1, .7, .7);

    // Environment light
    col += (cos(refl.x * 10.) * .5 + .5) / 32. * vec3(.75, .6, 1.);
    
    // Post-processing and output
    col *= 1. - smoothstep(0., 3., length(uv2));
    col += 1. / 210.;
    col *= 2.;
    col /= (col + 1.) * .85;

    fragColor = vec4(sqrt(max(col, 0.) * 1.05), 1.) +
                texelFetch(iChannel1, ivec2(fragCoord) & 1023,0).r / 256.;
}

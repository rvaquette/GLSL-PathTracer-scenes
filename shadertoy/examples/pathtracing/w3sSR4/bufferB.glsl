
vec3 tex(vec2 p)
{
    vec4 O = texture(iChannel0, clamp(p, 0., 1.));
    return O.xyz / O.w;
}

void mainImage(out vec4 O, vec2 I)
{
    O = vec4(0);
    
    if(iFrame < 2 && SKYTYPE > 1) return;
    
    seed = uvec4(I, iFrame, iTime);
    
    // TO DO: Bloom and Halation
    
    if(texelFetch(iChannel2, ivec2(32, 0), 0).x < .5) O = texelFetch(iChannel1, ivec2(I), 0);
    
    O += vec4(tex(I / R.xy), 1);
}

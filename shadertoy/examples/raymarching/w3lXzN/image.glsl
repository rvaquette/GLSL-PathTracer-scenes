
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec3 col = texture(iChannel0, uv).rgb;
    col = pow(col, vec3(1./2.2));
    
    fragColor = vec4(col,1);
}


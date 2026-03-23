void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec4 texColor = texture(iChannel0, fragCoord / iResolution.xy);
    
    // Gamma correction
    fragColor.xyz = pow(texColor.rgb, vec3(1.0/2.2));
}

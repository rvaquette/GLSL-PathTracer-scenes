void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    fragColor = blur(iChannel0, fragCoord, iResolution.xy);
}

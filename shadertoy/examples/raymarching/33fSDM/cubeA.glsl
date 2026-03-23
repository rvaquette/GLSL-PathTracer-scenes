// Background image (linear colors)

void mainCubemap( out vec4 fragColor, in vec2 fragCoord, in vec3 rayOri, in vec3 rayDir )
{
    fragColor = pow(texture(iChannel0,rayDir),vec4(2.2));

    //increase dynamic range
    fragColor.rgb = HLG(fragColor.rgb);
}

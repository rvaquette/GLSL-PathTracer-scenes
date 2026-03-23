void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    
    vec4 newCol = texture(iChannel1, uv);
    
    float resolutionChangeFlag = texelFetch(iChannel0, ivec2(INFO_RESOLUTION_POS, 0), 0).x;
        
    if (isMouseDown || (resolutionChangeFlag == 1.))
        fragColor = newCol;
    else {
        int lastFrame = int(texelFetch(iChannel0, ivec2(INFO_FRAME_POS, 0), 0).x);
        vec4 lastCol = texture(iChannel2, uv);
        
        fragColor = lastCol * (1. - 1./float((iFrame - lastFrame) + 1)) + newCol * 1./float((iFrame - lastFrame) + 1);
    }
}



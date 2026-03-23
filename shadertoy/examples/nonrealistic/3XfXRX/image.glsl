// from CPSC591 PA2
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 r = texture(iChannel0, uv);
    
    // gamma
    #ifdef XTOON_ON
        fragColor = r;
        return;
    #endif
    r = clamp(r,0.0,1.0);
	r = vec4( pow( r , vec4(1.0/2.2)));    
    
    fragColor =  r;
}
